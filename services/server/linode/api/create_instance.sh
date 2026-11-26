#!/bin/sh
#: Name:        create_instance.sh
#: Purpose:     Provisions a Linode compute instance directly via the Linode REST API v4.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       printf '%s\n' "<region> <image> <server_size> <server_name> <firewall_id> <subnet_id> <user_data_path>" | create_instance.sh
#:              create_instance.sh [-h|--help]
#:
#: Parameters:
#:   stdin      [Required] Space-separated payload: "region image server_size server_name firewall_id subnet_id user_data_path"
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/.ssh/EMERGENCY_PASSWORD
#:   - External binaries: cat, echo, printf, grep, cut, sed, tr, base64, jq, curl
#:
#: Exit Codes:
#:   0          Linode instance creation payload accepted by API (JSON body printed to stdout)
#:   1          Missing /home/homedir.dat, invalid stdin payload, missing secret/files, or non-2xx API error
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

# Verify stdin is a pipe or redirected file, not an interactive terminal
if [ -t 0 ]
then
        /bin/echo "Error: Deployment parameters must be piped via stdin to protect process trees." >&2
        exit 1
fi

if ! read -r parameter_payload
then
        /bin/echo "Error: Failed to read deployment payload from stdin." >&2
        exit 1
fi

set -- ${parameter_payload}

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
firewall_id="${5}"
subnet_id="${6}"
user_data_path="${7}"

if [ -z "${region}" ] || [ -z "${image}" ] || [ -z "${server_size}" ] || [ -z "${server_name}" ] || [ -z "${firewall_id}" ] || [ -z "${subnet_id}" ] || [ -z "${user_data_path}" ]
then
        /bin/echo "Error: Missing required fields in deployment parameter payload." >&2
        exit 1
fi

if [ ! -f "${user_data_path}" ] || [ ! -r "${user_data_path}" ]
then
        /bin/echo "Error: Cannot read user data script at ${user_data_path}" >&2
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

password_file="${HOME}/.ssh/EMERGENCY_PASSWORD"
emergency_password=""
if [ -f "${password_file}" ]
then
        if [ ! -r "${password_file}" ]
        then
                /bin/echo "Error: Password file exists but is unreadable at ${password_file}" >&2
                exit 1
        fi
        emergency_password="$(/bin/cat "${password_file}")"
fi

if [ -z "${emergency_password}" ]
then
        /bin/echo "Error: Emergency password missing or empty at ${password_file}." >&2
        exit 1
fi

if [ ! -x /usr/bin/base64 ] || [ ! -x /usr/bin/jq ] || [ ! -x /usr/bin/curl ]
then
        /bin/echo "Error: Required binaries (base64, jq, or curl) missing or not executable." >&2
        exit 1
fi

user_data_encoded="$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')"

if [ -z "${user_data_encoded}" ]
then
        /bin/echo "Error: Failed to process or encode user data at ${user_data_path}" >&2
        exit 1
fi

# Assemble Linode v4 instance payload; omit firewall_id when sentinel -1 is supplied
instance_payload="$(/usr/bin/jq -n -c \
        --arg pass "${emergency_password}" \
        --arg reg "${region}" \
        --arg img "${image}" \
        --arg size "${server_size}" \
        --arg name "${server_name}" \
        --arg fw "${firewall_id}" \
        --arg sub "${subnet_id}" \
        --arg ud "${user_data_encoded}" \
        '(
                {
                        vpc: {
                                subnet_id: ($sub | tonumber),
                                ipv4: {
                                        addresses: [
                                                { address: "auto", nat_1_1_address: "auto" }
                                        ]
                                }
                        }
                }
                + (if ($fw | tonumber) >= 0 then { firewall_id: ($fw | tonumber) } else {} end)
        ) as $iface
        | {
                root_pass: $pass,
                region: $reg,
                image: $img,
                type: $size,
                label: $name,
                interface_generation: "linode",
                interfaces: [ $iface ],
                metadata: { user_data: $ud },
                disk_encryption: "enabled"
        }' 2>/dev/null)"

if [ -z "${instance_payload}" ]
then
        /bin/echo "Error: Failed to construct valid instance configuration JSON." >&2
        exit 1
fi

set +e
RESPONSE="$(printf 'Authorization: Bearer %s\n' "${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 60 -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}" -w "\nHTTP_STATUS:%{http_code}")"
set -e

HTTP_CODE="$(printf '%s\n' "${RESPONSE}" | /bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(printf '%s\n' "${RESPONSE}" | /bin/sed '/HTTP_STATUS:/d')"

case "${HTTP_CODE}" in
        200|201)
                printf '%s\n' "${RESPONSE_BODY}"
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check your payload syntax." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Check your TOKEN." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Missing permissions." >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Linode Server Error." >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Unexpected response." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0

