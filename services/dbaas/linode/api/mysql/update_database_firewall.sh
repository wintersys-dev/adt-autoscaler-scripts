#!/bin/sh
###################################################################################
# @file        update_database.sh
# @brief       Updates the allow list configuration for a managed Linode MySQL database via REST API.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script extracts infrastructure authentication tokens via secure standard
#              input piping, formats the allow-list entries into a strict JSON payload,
#              and executes an authenticated curl PUT request under a status monitoring
#              block to apply updated firewall rules to the target MySQL database instance.
#
# @param       $1  [Required] The unique numerical identifier of the target MySQL database.
# @param       $2  [Required] The allow-list IP/CIDR entries (space-separated, CLI flags, or JSON).
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/utilities/config/ExtractConfigValue.sh
#              - external dependencies: cat, echo, printf, tr, sed, grep, cut, jq, curl
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Routes Bearer tokens via curl stdin config (-K -) to prevent exposure in ps.
#              - Builds JSON payloads via jq to eliminate string-concatenation injection vectors.
#              - Quotes variable interpolations thoroughly and unsets tokens post-execution.
#
# @exit        0  Success: Target MySQL database allow list updated cleanly.
# @exit        *  Failure: Missing arguments, layout faults, invalid payload construction,
#                 or a non-2xx status code thrown back by the remote endpoint.
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
#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: database_id and allow_list are required." >&2
        /bin/echo "Usage: $0 <database_id> <allow_list>" >&2
        exit 1
fi

database_id="${1}"
allow_list="${2}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

# Construct a valid JSON payload {"allow_list": [...]} safely using jq
if /usr/bin/printf '%s' "${allow_list}" | /usr/bin/jq -e . >/dev/null 2>&1
then
        if /usr/bin/printf '%s' "${allow_list}" | /usr/bin/jq -e 'type == "array"' >/dev/null 2>&1
        then
                JSON_PAYLOAD="$(/usr/bin/printf '%s' "${allow_list}" | /usr/bin/jq -c '{allow_list: .}')"
        else
                JSON_PAYLOAD="$(/usr/bin/printf '%s' "${allow_list}" | /usr/bin/jq -c '.')"
        fi
else
        # Strip any legacy --allow_list flags and convert space-delimited CIDRs to a JSON array
        CLEAN_IPS="$(/usr/bin/printf '%s' "${allow_list}" | /usr/bin/sed 's/--allow_list//g' | /usr/bin/tr -s ' ' '\n' | /usr/bin/grep -v '^$')"
        JSON_PAYLOAD="$(/usr/bin/printf '%s\n' "${CLEAN_IPS}" | /usr/bin/jq -R -s -c 'split("\n") | map(select(length > 0)) | {allow_list: .}')"
fi

if [ -z "${JSON_PAYLOAD}" ]
then
        /bin/echo "Error: Failed to construct valid JSON allow_list payload." >&2
        exit 1
fi

set +e
# Safely route authorized PUT actions via curl stdin config (-K -) to prevent token exposure in process trees
RESPONSE=$(/usr/bin/printf 'header = "Authorization: Bearer %s"\n' "${TOKEN}" | /usr/bin/curl -K - -s -X PUT -H "Content-Type: application/json" -d "${JSON_PAYLOAD}" "https://api.linode.com/v4/databases/mysql/instances/${database_id}" -w "\nHTTP_STATUS:%{http_code}")
set -e

unset TOKEN

# Extract the HTTP status code (e.g., 200, 404, 401) using strict POSIX filtering
HTTP_CODE=$(/bin/echo "$RESPONSE" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw JSON response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "$RESPONSE" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200)
        /bin/echo "Success: Linode Database MySQL Update for ${database_id} applied correctly."
        exit 0
        ;;
    400)
        /bin/echo "Error 400: Bad Request. Check allow_list CIDR syntax or endpoint schema." >&2
        /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
        exit 400
        ;;
    401)
        /bin/echo "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired." >&2
        exit 401
        ;;
    403)
        /bin/echo "Error 403: Forbidden. Token lacks read_write permissions for managed databases." >&2
        exit 403
        ;;
    404)
        /bin/echo "Error 404: Not Found. Linode MySQL database ${database_id} does not exist." >&2
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
