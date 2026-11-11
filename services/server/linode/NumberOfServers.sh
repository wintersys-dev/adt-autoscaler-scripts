#!/bin/sh
############################################################################################
# @file        NumberOfServers.sh
# @brief       Counts the number of active Linode servers containing a specific type string.
# @author      Peter Winter
# @date        13/07/2026
# @version     1.0
#
# @details     This script queries the Linode v4 API to fetch all active instances, 
#              then parses the JSON response using jq to determine how many server 
#              labels match or contain the provided 'server_type' substring. It acts 
#              as an integrated module within the Agile Deployment Toolkit.
#
# @param       $1  [Required] The server type substring to search for within instance labels.
#
# @env         HOME                Path to the core toolchain root directory (read from file).
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
# @exit        0  Success: A count was calculated and printed to stdout.
# @exit        1  Failure: Missing arguments, missing configurations, invalid token, 
#                 network timeouts, or API payload execution issues.
############################################################################################
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
##########################################################################################
##########################################################################################
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
        /bin/echo "Error: Server type argument is required."  >&2
        /bin/echo "Usage: $0 <server_type>"  >&2
        exit 1
fi

server_type="${1}"

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

# Secure framework configuration value extraction
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(${HOME}/services/server/linode/${orchestration_tool}/list_instances.sh "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg search "${server_type}" '[.[] | select(.label | contains($search))] | length')"

        if [ -z "${output}" ]
        then
                /bin/echo "Error: No matching server instance found for server type ${server_type}."  >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "Network request failed. Check your API token or URL."  >&2
        exit 1
fi

exit 0
