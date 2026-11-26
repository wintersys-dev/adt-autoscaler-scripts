#!/bin/sh
#: Name:        delete_record.sh
#: Purpose:     Deletes a specific DNS record from a Linode domain via REST API v4.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       delete_record.sh <domain_id> <record_id>
#:              delete_record.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Unique numerical identifier of the target Linode DNS domain
#:   $2         [Required] Unique numerical identifier of the target Linode DNS record
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, curl
#:
#: Exit Codes:
#:   0          Target DNS domain record deleted cleanly
#:   1          Missing /home/homedir.dat, missing arguments, missing TOKEN, or API/network failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Domain ID and Record ID arguments are required." >&2
        /bin/echo "Usage: $0 <domain_id> <record_id>" >&2
        exit 1
fi

domain_id="${1}"
record_id="${2}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

set +e
RESPONSE="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -sS -X DELETE "https://api.linode.com/v4/domains/${domain_id}/records/${record_id}" -w "\nHTTP_STATUS:%{http_code}" 2>&1)"
CURL_EXIT="$?"
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        /bin/echo "Error: curl transport failed with exit code ${CURL_EXIT}: ${RESPONSE}" >&2
        exit 1
fi

HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

case "${HTTP_CODE}" in
        200|204)
                /bin/echo "Success: DNS record ${record_id} deleted cleanly from domain ${domain_id}." >&2
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check syntax or target endpoint schema." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Token lacks permissions to delete DNS records under domain ${domain_id}." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Domain ${domain_id} or record ${record_id} does not exist." >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Linode Gateway or Remote Server Exception." >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

