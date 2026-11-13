#!/bin/sh
###################################################################################
# @file        create_record.sh
# @brief       Creates a new DNS zone or DNS record on Linode via REST API.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.2
#
# @details     This script validates the JSON payload argument, routes to either the
#              master zone endpoint (when domain_id is empty) or the domain records
#              endpoint (when domain_id is provided), exports infrastructure tokens
#              via secure stdin piping, and executes an authenticated curl POST request.
#
# @param       $1  [Optional] Numerical identifier of the target DNS domain (empty for new zone).
# @param       $2  [Required] The JSON payload defining the DNS zone or record attributes.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, curl, grep, cut, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Passes bearer tokens via stdin (-H @-) to prevent exposure in process listings.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: DNS zone or record created cleanly.
# @exit        *  Failure: Missing arguments, layout faults, missing context variables, or 
#                 a non-2xx status code thrown back by the remote endpoint.
##################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi


if [ -z "${2}" ]
then
        /bin/echo "Error: JSON payload argument is required." >&2
        /bin/echo "Usage: $0 <domain_id_or_empty> <json_payload>" >&2
        exit 1
fi

domain_id="${1}"
json_payload="${2}"

api_host="https://api.linode.com"
api_path="v4/domains"

if [ "${domain_id}" = "zone" ]
then
        endpoint="${api_host}/${api_path}"
else
        endpoint="${api_host}/${api_path}/${domain_id}/records"
fi

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X POST -H "Content-Type: application/json" -d "${json_payload}" "${endpoint}" -w "\nHTTP_STATUS:%{http_code}")
set -e

HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${HTTP_CODE}" in
        200|201)
                /bin/echo "${RESPONSE_BODY}" | /usr/bin/jq '.data'
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check JSON payload syntax or schema." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 400
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired." >&2
                exit 401
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Token lacks permissions for this DNS operation." >&2
                exit 403
                ;;
        404)
                /bin/echo "Error 404: Not Found. Target Linode domain does not exist." >&2
                exit 404
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 429
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Linode Gateway or Remote Server Exception." >&2
                exit 500
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0
