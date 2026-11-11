#!/bin/sh
###################################################################################
# @file        shutdown_instance.sh
# @brief       Issues a power shutdown command to a Linode server via the REST API v4.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script exports infrastructure authentication tokens via secure standard
#              input piping, validates the target server identity parameter, and
#              executes an authenticated curl POST request under a strict status
#              monitoring block to cleanly initiate an ACPI shutdown sequence.
#
# @param       $1  [Required] The API access or authentication token for the Linode API.
# @param       $2  [Required] The unique numerical identifier of the target server instance.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, curl
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Shutdown request for the server instance accepted by API server.
# @exit        *  Failure: Missing arguments, layout faults, or a non-2xx status 
#                 code thrown back by the remote endpoint.
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
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

if [ -z "${1}" ] 
then
        /bin/echo "Error: Server ID argument is required." >&2
        /bin/echo "Usage: $0 <server_id>" >&2
        exit 1
fi

server_id="${1}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if  [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

set +e
# Safely route authorized POST actions via standard stream piping to prevent exposure in process trees
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X POST "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" -w "\nHTTP_STATUS:%{http_code}")
set -e
# Extract the HTTP status code (e.g., 200, 404, 401) using strict POSIX filtering
HTTP_CODE=$(/bin/echo "$RESPONSE" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "$RESPONSE" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200)
        # This streams the pure JSON (empty dictionary {} on success) back to the caller's stdout
        /bin/echo "${RESPONSE_BODY}"
        exit 0
        ;;
    400)
        /bin/echo "Error 400: Bad Request. The instance may already be in the requested state or misconfigured." >&2
        /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
        exit 400
        ;;
    401)
        /bin/echo "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired." >&2
        exit 401
        ;;
    403)
        /bin/echo "Error 403: Forbidden. Token lacks permissions to modify power states on this instance." >&2
        exit 403
        ;;
    404)
        /bin/echo "Error 404: Not Found. Linode instance ${server_id} does not exist." >&2
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
