#!/bin/sh
############################################################################
# @file        GetServerPublicIPAddressByPrivateIPAddress.sh
# @brief       Resolves a machine's public NAT IP based on its private VPC IP.
# @author      Peter Winter
# @date        13/06/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 VPC IPs endpoint to query 
#              network address configurations. It searches the dataset for the 
#              provided private IP address and extracts its mapped public IPv4 
#              address via the 'nat_1_1' metadata attribute using jq.
#
# @param       $1  [Required] The target private VPC IPv4 address to translate.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
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
# @exit        0  Success: The public NAT IP was found and printed to stdout.
# @exit        1  Failure: Missing arguments, invalid token, network timeouts, or 
#                 no matching 1:1 NAT mapping exists for the given private IP.
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
        /bin/echo "Error: Server ip argument is required." >&2
        /bin/echo "Usage: $0 <server_ip>" >&2
        exit 1
fi

server_ip="${1}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REGION')"
set -e

software_file="${BUILD_HOME}/runtime/software.dat"
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
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.address == $ip).nat_1_1')"

        if [ -z "${output}" ] || [ "${output}" = "null" ]
        # Ensure a valid NAT string was found
        then
                /bin/echo "Error: No matching public IP address found for server ip ${server_ip}."  >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "Network request failed. Check your API token or URL."  >&2
        exit 1
fi

exit 0
