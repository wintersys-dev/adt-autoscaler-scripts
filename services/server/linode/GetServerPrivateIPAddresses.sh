#!/bin/sh
#: Name:        GetServerPrivateIPAddresses.sh
#: Purpose:     Resolves private VPC IPv4 addresses for all Linode instances matching a server type/label.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPrivateIPAddresses.sh <server_type>
#:              GetServerPrivateIPAddresses.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Server type prefix or machine label substring used to resolve server IDs
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/services/server/linode/ListServerIDs.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/get_instance_ips.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          Private VPC IPv4 address(es) resolved and printed cleanly (or empty when no instances exist)
#:   1          Missing /home/homedir.dat, missing argument, missing driver/config, or IP lookup failure
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
        /bin/echo "Error: Server type argument is required." >&2
        /bin/echo "Usage: ${0} <server_type>" >&2
        exit 1
fi

server_type="${1}"

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

list_ids_script="${HOME}/services/server/linode/ListServerIDs.sh"
get_ips_script="${HOME}/services/server/linode/${orchestration_tool}/get_instance_ips.sh"

if [ ! -x "${list_ids_script}" ] || [ ! -x "${get_ips_script}" ]
then
        /bin/echo "Error: Required Linode helper scripts missing or not executable under ${HOME}/services/server/linode/." >&2
        exit 1
fi

if [ ! -x /usr/bin/jq ]
then
        /bin/echo "Error: /usr/bin/jq not found or not executable." >&2
        exit 1
fi

set +e
server_ids="$("${list_ids_script}" "${server_type}")"
ids_status="$?"
set -e

if [ "${ids_status}" -ne 0 ]
then
        /bin/echo "Error: Failed to list Linode server IDs for '${server_type}'." >&2
        exit 1
fi

if [ -z "${server_ids}" ]
then
        exit 0
fi

for id in ${server_ids}
do
        set +e
        response="$("${get_ips_script}" "${id}")"
        ip_status="$?"
        set -e

        if [ "${ip_status}" -eq 0 ] && [ -n "${response}" ]
        then
                output="$(printf '%s\n' "${response}" | /usr/bin/jq -r '(.ipv4.vpc // [])[] | .address')"

                if [ -z "${output}" ] || [ "${output}" = "null" ]
                then
                        /bin/echo "Error: No matching private IP address found for server ID ${id}." >&2
                        exit 1
                else
                        /bin/echo "${output}"
                fi
        else
                /bin/echo "Error: Network request failed when querying IPs for server ID ${id}." >&2
                exit 1
        fi
done

exit 0

