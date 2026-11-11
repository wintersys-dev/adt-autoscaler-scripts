#!/bin/sh
###################################################################################
# @file        TerminateServer.sh
# @brief       Gracefully shuts down and permanently deletes a Linode server by IP.
# @author      Peter Winter
# @date        13/07/2026
# @version     1.0
#
# @details     This script orchestrates the destruction of a specific Linode instance.
#              It resolves the instance ID via its IPv4 address, issues a shutdown 
#              POST request, polls the API up to 21 times (3.5 minutes) waiting for 
#              an 'offline' status, and finally executes a permanent DELETE request.
#
# @param       $1  [Required] The target IPv4 address of the instance to destroy.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - GetServerName.sh helper resolution tool tracking instance labels by IP.
#              - ListServerIDs.sh helper resolution tool translating instance labels into IDs.
#              - external dependencies: curl, jq, expr, sleep, cat, mkdir, dirname, date
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
#
# @exit        0  Success: The instance was successfully shut down and deleted.
# @exit        1  Failure: Missing arguments, missing configuration, api communication 
#                 errors, or failure during the deletion sequence.
###################################################################################
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
###################################################################################
###################################################################################
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
        /bin/echo "Error: Server ip argument is required." >&2
        /bin/echo "Usage: $0 <server_ip>" >&2
        exit 1
fi

server_ip="${1}"


software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
    /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
    exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
    /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
    exit 1
fi

server_name="$("${HOME}/services/server/linode/GetServerName.sh" "${server_ip}")"

if [ -n "${server_name}" ] 
then
        server_id="$("${HOME}/services/server/linode/ListServerIDs.sh" "${server_name}")"
        
        /bin/echo "Initiating graceful shutdown for instance '${server_name}' (ID: ${server_id}, IP: ${server_ip})..." >&2
        
        # Dispatch shutdown request securely
        ${HOME}/services/server/linode/${orchestration_tool}/shutdown_instance.sh "${server_id}"
        count="0"
        while true
        do
                # Fetch target runtime instance environment state tracking flags safely
                current_status="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/get_instance_status.sh  "${server_id}")"  
                if [ "${current_status}" = "offline" ] || [ "${count}" -ge 21 ]
                then
                        break
                fi

                /bin/echo "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="$(/usr/bin/expr "${count}" + 1)"
        done

        /bin/echo "Executing permanent deletion routine for instance ID: ${server_id}..."
        
        # Dispatch final removal payload transaction securely
        ${HOME}/services/server/linode/${orchestration_tool}/delete_instance.sh "${server_id}"
        /bin/echo "Machine with id: ${server_id} and ip address ${server_ip} has been deleted"
else
        /bin/echo "Error: No active server instance records matched IP tracking descriptor '${server_ip}'." >&2
        exit 1
fi

exit 0
