#!/bin/sh
#: Name:        TerminateServer.sh
#: Purpose:     Gracefully shuts down and permanently deletes a Linode server instance by IPv4 address.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       TerminateServer.sh <server_ip>
#:              TerminateServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target IPv4 address of the Linode server instance to destroy
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/services/server/linode/GetServerName.sh
#:   - ${HOME}/services/server/linode/ListServerIDs.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/shutdown_instance.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/get_instance_status.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/delete_instance.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, tr, head, sleep
#:
#: Exit Codes:
#:   0          Linode server instance shut down and deleted cleanly
#:   1          Missing /home/homedir.dat, invalid IP argument, unresolved instance, or deletion failure
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
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

if [ -z "${1}" ]
then
        /bin/echo "Error: Server IP address argument is required." >&2
        /bin/echo "Usage: ${0} <server_ip>" >&2
        exit 1
fi

server_ip="${1}"

if ! printf '%s\n' "${server_ip}" | /usr/bin/grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
then
        /bin/echo "Error: Invalid IPv4 address format '${server_ip}'." >&2
        exit 1
fi

software_file="${HOME}/runtime/software.dat"
if [ ! -r "${software_file}" ]
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

linode_dir="${HOME}/services/server/linode"
driver_dir="${linode_dir}/${orchestration_tool}"

for req_script in \
        "${linode_dir}/GetServerName.sh" \
        "${linode_dir}/ListServerIDs.sh" \
        "${driver_dir}/shutdown_instance.sh" \
        "${driver_dir}/get_instance_status.sh" \
        "${driver_dir}/delete_instance.sh"
do
        if [ ! -x "${req_script}" ]
        then
                /bin/echo "Error: Required Linode helper script missing or not executable at ${req_script}" >&2
                exit 1
        fi
done

set +e
server_name="$("${linode_dir}/GetServerName.sh" "${server_ip}")"
name_status="$?"
set -e

if [ "${name_status}" -ne 0 ] || [ -z "${server_name}" ]
then
        /bin/echo "Error: No active server instance records matched IP address '${server_ip}'." >&2
        exit 1
fi

set +e
server_id="$("${linode_dir}/ListServerIDs.sh" "${server_name}" | /usr/bin/head -n 1)"
id_status="$?"
set -e

if [ "${id_status}" -ne 0 ] || [ -z "${server_id}" ]
then
        /bin/echo "Error: Failed to resolve Linode instance ID for server '${server_name}'." >&2
        exit 1
fi

/bin/echo "Initiating graceful shutdown for instance '${server_name}' (ID: ${server_id}, IP: ${server_ip})..."

set +e
"${driver_dir}/shutdown_instance.sh" "${server_id}" >/dev/null 2>&1
set -e

count=0
while true
do
        set +e
        current_status="$("${driver_dir}/get_instance_status.sh" "${server_id}" 2>/dev/null)"
        set -e

        if [ "${current_status}" = "offline" ] || [ "${count}" -ge 21 ]
        then
                break
        fi

        /bin/echo "Waiting for machine with ID ${server_id} and IP address ${server_ip} to be offline following a shutdown request"
        /bin/sleep 10
        count=$((count + 1))
done

/bin/echo "Executing permanent deletion routine for instance ID: ${server_id}..."

"${driver_dir}/delete_instance.sh" "${server_id}"
/bin/echo "Machine with ID ${server_id} and IP address ${server_ip} has been deleted"

exit 0

