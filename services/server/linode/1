#!/bin/sh
############################################################################
# @file        GetServerPrivateIPAddressByPublicIPAddress.sh
# @brief       Resolves a machine's private VPC IP based on its public NAT IP.
# @author      Peter Winter
# @date        13/06/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 VPC IPs endpoint to query 
#              network address configurations. It searches the dataset for the 
#              provided public IP address via the 'nat_1_1' attribute and extracts 
#              its mapped private IPv4 address using jq.
#
# @param       $1  [Required] The target public IPv4 address to translate.
#
# @env         HOME                Path to the framework root directory (read from file).
# @env         REGION              The region that the servers are running in.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: curl, jq, cat, mkdir, dirname, date, echo
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
#
# @exit        0  Success: The private VPC IP was found and printed to stdout.
# @exit        1  Failure: Missing arguments, invalid token, network timeouts, or 
#                 no matching private VPC IP exists for the given public IP.
#############################################################################
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
####################################################################################
#set -x
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ]
then
        /bin/echo "Error: Server public ip argument is required." >&2
        /bin/echo "Usage: $0 <server_public_ip>" >&2
        exit 1
fi

server_ip="${1}"

set +e
#TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REGION')"
set -e

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
    /bin/echo "Error: Cannot read software configuration file at ${software_file}"  >&2
    exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
    /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}"  >&2
    exit 1
fi

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(${HOME}/services/server/linode/${orchestration_tool}/get_vpc_ips.sh "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.nat_1_1 == $ip).address')"

        if [ -z "${output}" ] || [ "${output}" = "null" ]
        # Ensure a valid private VPC IP string was found
        then
                /bin/echo "Error: No matching private IP address found for public ip ${server_ip}."  >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "Network request failed. Check your API token or URL."  >&2
        exit 1
fi

exit 0
