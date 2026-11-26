#!/bin/sh
#: Name:        delete_record.sh
#: Purpose:     Deletes a specific DNS record from a Cloudflare zone via REST API v4.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       delete_record.sh <zone_id> <record_id>
#:              delete_record.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Unique Cloudflare identifier of the target DNS zone
#:   $2         [Required] Unique Cloudflare identifier of the target DNS record
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, echo, printf, grep, cut, sed, tr, curl
#:
#: Exit Codes:
#:   0          Cloudflare DNS record deleted cleanly and response JSON printed to stdout
#:   1          Missing /home/homedir.dat, missing arguments, missing credentials, or API failure
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

# Resolve HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: zone_id and record_id parameters are required." >&2
        /bin/echo "Usage: $0 <zone_id> <record_id>" >&2
        exit 1
fi

# Strip any accidental whitespace/newlines from parameters to prevent curl exit code 3
zone_id="$(printf '%s' "${1}" | /usr/bin/tr -d '[:space:]')"
record_id="$(printf '%s' "${2}" | /usr/bin/tr -d '[:space:]')"

if [ -z "${zone_id}" ] || [ -z "${record_id}" ]
then
        /bin/echo "Error: zone_id or record_id is empty after whitespace removal." >&2
        exit 1
fi

set +e
DNS_USERNAME="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSUSERNAME')"
DNS_SECURITY_KEY="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSSECURITYKEY')"
set -e

if [ -z "${DNS_SECURITY_KEY}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (DNSSECURITYKEY)." >&2
        exit 1
fi

API_URL="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}"

# Build authentication headers via stdin and execute request
set +e
case "${DNS_SECURITY_KEY}" in
        *::*)
                api_token="${DNS_SECURITY_KEY#*:::}"
                RESPONSE="$(printf 'Authorization: Bearer %s\n' "${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X DELETE "${API_URL}" -H "Content-Type: application/json" 2>&1)"
                ;;
        *)
                RESPONSE="$(printf 'X-Auth-Email: %s\nX-Auth-Key: %s\n' "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X DELETE "${API_URL}" -H "Content-Type: application/json" 2>&1)"
                ;;
esac
CURL_EXIT="$?"
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        /bin/echo "Error: curl failed with exit code ${CURL_EXIT} while deleting record ${record_id}." >&2
        /bin/echo "Detail: ${RESPONSE}" >&2
        exit 1
fi

# Extract HTTP status code and response body using strict POSIX filtering
HTTP_CODE="$(printf '%s\n' "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(printf '%s\n' "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate the API response code
case "${HTTP_CODE}" in
        200|201)
                printf '%s\n' "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check zone_id (${zone_id}) or record_id (${record_id}) format." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Credentials lack permission to delete DNS records for this zone." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Verify that zone_id (${zone_id}) and record_id (${record_id}) exist." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Cloudflare API or Upstream Server Exception." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE:-UNKNOWN}: Unexpected response from Cloudflare API." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac


