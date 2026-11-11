#!/bin/sh
###################################################################################
# @file        create_instance.sh
# @brief       Provisions a Linode server instance directly via the Linode REST API v4.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script extracts deployment configuration metadata from a single input
#              payload string, resolves environmental contexts, handles or generates
#              root emergency passwords, base64 encodes initialization scripts, builds 
#              a structured JSON definition, and safely delivers a POST request to 
#              the cloud API endpoints using authenticated curl pipelines.
#
# @param       $1  [Required] Space-separated deployment parameters payload string:
#                  "region image server_size server_name firewall_id subnet_id user_data_path"
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, tr, cut, openssl, jq, base64, curl
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to negate hijacking.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Cloud instance creation payload accepted by API server.
# @exit        *  Failure: Missing arguments, layout faults, encoding failures, 
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
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Verify stdin is a pipe or a redirected file, not a terminal
if [ -t 0 ]
then
        /bin/echo "Error: Deployment parameters must be piped via stdin to protect process trees." >&2
        exit 1
fi

# Read the single-line payload from standard input safely
if ! read -r parameter_payload
then
        /bin/echo "Error: Failed to read deployment payload from stdin." >&2
        exit 1
fi

set -- $parameter_payload

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
firewall_id="${5}"
subnet_id="${6}"
user_data_path="${7}"

# Ensure all expected payload arguments extracted successfully and are not empty
if [ -z "${region}" ] || [ -z "${image}" ] || [ -z "${server_size}" ] || [ -z "${server_name}" ] || [ -z "${firewall_id}" ] || [ -z "${subnet_id}" ] || [ -z "${user_data_path}" ]
then
        /bin/echo "Error: Missing required fields in deployment parameter payload." >&2
        exit 1
fi

# Validate existence and accessibility of the user data script file before proceeding
if [ ! -f "${user_data_path}" ] || [ ! -r "${user_data_path}" ]
then
        /bin/echo  "Error: Cannot read user data script at ${user_data_path}" >&2
        exit 1
fi


set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
CLOUDHOST="$(${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST')"
BUILD_IDENTIFIER="$(${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER')"
set -e


if [ -z "${TOKEN}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN, CLOUDHOST, or BUILD_IDENTIFIER)." >&2
        exit 1
fi

# Set up and isolate runtime host state tracking hierarchy
runtime_dir="${HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

password_file="${HOME}/.ssh/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then    
        if [ ! -r "${password_file}" ]
        then
                /bin/echo "Error: Password file exists but is unreadable at ${password_file}" >&2
                exit 1
        fi
        emergency_password="$(/bin/cat "${password_file}")"
else
        # Safely generate an alphanumeric random password sequence
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /bin/tr -d '\n' | /bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -c 1-16)"
        /bin/echo "${emergency_password}" > "${password_file}"
        /bin/chmod 600 "${password_file}"
fi

if [ -z "${emergency_password}" ]
then
        /bin/echo "Error: Emergency password variable isolation failed or resolved empty." >&2
        exit 1
fi

# Base64 encode user data cleanly (substituting portable redirection format over linux-specific flag combinations)
user_data_encoded="$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')"

if [ -z "${user_data_encoded}" ]
then
        /bin/echo "Error: Failed to process or encode user data at ${user_data_path}" >&2
        exit 1
fi

# Assemble complete deployment specification document using safely isolated arguments inside jq
instance_payload="$(/usr/bin/jq -n -c --arg pass "${emergency_password}" --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data_encoded}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }' 2>/dev/null)"

if [ -z "${instance_payload}" ]
then
        /bin/echo "Error: Failed to construct valid instance configuration JSON." >&2
        exit 1
fi

set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Extract the HTTP status code (last 3 digits after the marker)
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Strip the marker and code from the response body
RESPONSE_BODY=$(/bin/echo "$RESPONSE" | /bin/sed '/HTTP_STATUS:/d')

# Evaluate the response using a POSIX-compliant case statement
case "$HTTP_CODE" in
        200|201)
                /bin/echo "$RESPONSE_BODY"
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check your payload syntax." >&2
                /bin/echo "API Response: $RESPONSE_BODY" >&2
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
                /bin/echo "Error $HTTP_CODE: Linode Server Error." >&2
                exit 1
                ;;
        *)
                /bin/echo "Error $HTTP_CODE: Unexpected response." >&2
                /bin/echo "API Response: $RESPONSE_BODY" >&2
                exit 1
                ;;
esac

exit 0
