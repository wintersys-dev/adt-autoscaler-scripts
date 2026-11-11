#!/bin/sh
#########################################################################################
# @file        GetServerPrivateIPAddresses.sh
# @brief       Retrieves the private VPC IPv4 addresses for a given server type.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script queries the local toolkit environment to identify target 
#              server IDs matching a specific type string. It then loops through each 
#              ID, hits the Linode v4 IPs endpoint, and extracts the associated 
#              private VPC address fields using jq filtering.
#
# @param       $1  [Required] The server type/name substring used to resolve server IDs.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
# @env         REGION              The region that the servers are running in.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ListServerIDs.sh helper resolution tool translating instance labels into IDs.
#              - external dependencies: curl, jq, cat, mkdir, dirname, date, echo
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
#
# @exit        0  Success: One or more private IP addresses were resolved and printed.
# @exit        1  Failure: Missing arguments, invalid token, network timeouts, or 
#                 no valid VPC IP assignments were found for the matching servers.
########################################################################################
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
########################################################################################
########################################################################################
#set -x
set -e

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
        /bin/echo "Error: Server type argument is required." >&2
        /bin/echo "Usage: $0 <server_type>" >&2
        exit 1
fi

server_type="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

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

server_ids="$("${HOME}/services/server/linode/ListServerIDs.sh" "${server_type}")"

set +e
response="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_instances.sh "${TOKEN}" "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        for id in ${server_ids}
        do
                # Temporary disable set -e for sub-calls inside the iteration loop
                set +e
                response1="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/get_instance_ips.sh "${id}")"
                curl_sub_status="$?"
                set -e

                if [ "${curl_sub_status}" -eq 0 ] && [ -n "${response1}" ]
                then
                        output="$(/bin/echo "${response1}" | /usr/bin/jq -r '.ipv4.vpc[] | .address')"

                        if [ -z "${output}" ]
                        then
                                /bin/echo "Error: No matching private ip address found for server id ${id}."  >&2
                                exit 1
                        else
                                /bin/echo "${output}"
                        fi
                else
                        /bin/echo "Error: Network request failed when querying IPs for server ID ${id}."  >&2
                        exit 1
                fi
        done
else
        /bin/echo "Network request failed. Check your API token or URL."  >&2
        exit 1
fi

exit 0
