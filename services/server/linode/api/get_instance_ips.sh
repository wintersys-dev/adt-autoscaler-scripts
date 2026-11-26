#!/bin/sh
#: Name:        get_instance_ips.sh
#: Purpose:     Retrieves allocated IP address metadata for a specific Linode instance via the REST API v4.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       get_instance_ips.sh <server_id>
#:              get_instance_ips.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Unique numeric identifier of the target Linode server instance
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, echo, printf, grep, cut, sed, curl
#:
#: Exit Codes:
#:   0          Target server IP networking JSON payload printed to stdout
#:   1          Missing /home/homedir.dat, invalid server ID, missing TOKEN, or non-2xx API error
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

# Resolve the server toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
        export HOME
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

if [ -z "${1}" ]
then
        /bin/echo "Error: Server ID argument is required." >&2
        /bin/echo "Usage: ${0} <server_id>" >&2
        exit 1
fi

server_id="${1}"

if ! printf '%s\n' "${server_id}" | /usr/bin/grep -Eq '^[0-9]+$'
then
        /bin/echo "Error: Invalid numeric Linode server ID '${server_id}'." >&2
        exit 1
fi

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
TOKEN="$("${extract_script}" 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (TOKEN)." >&2
        exit 1
fi

if [ ! -x /usr/bin/curl ]
then
        /bin/echo "Error: /usr/bin/curl not found or not executable." >&2
        exit 1
fi

set +e
RESPONSE="$(printf 'Authorization: Bearer %s\n' "${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 60 "https://api.linode.com/v4/linode/instances/${server_id}/ips" -w "\nHTTP_STATUS:%{http_code}")"
set -e

HTTP_CODE="$(printf '%s\n' "${RESPONSE}" | /bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(printf '%s\n' "${RESPONSE}" | /bin/sed '/HTTP_STATUS:/d')"

case "${HTTP_CODE}" in
        200)
                printf '%s\n' "${RESPONSE_BODY}"
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
                /bin/echo "Error 403: Forbidden. Token lacks permissions to look up network layouts." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Linode instance ${server_id} does not exist." >&2
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

