#!/bin/sh
#: Name:        ListServerIDs.sh
#: Purpose:     Lists Linode instance IDs whose labels match a given server type/label substring.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ListServerIDs.sh <server_type>
#:              ListServerIDs.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Server type prefix or machine label substring to match
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/services/server/linode/<orchestration_tool>/list_instances.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          Matching Linode instance ID(s) printed to stdout
#:   1          Missing /home/homedir.dat, missing argument/config, or no matching instance IDs
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

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
REGION="$("${extract_script}" 'REGION')"
set -e

if [ -z "${REGION}" ]
then
        /bin/echo "Error: Failed to retrieve REGION configuration value." >&2
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

list_script="${HOME}/services/server/linode/${orchestration_tool}/list_instances.sh"
if [ ! -x "${list_script}" ]
then
        /bin/echo "Error: Instance listing script missing or not executable at ${list_script}" >&2
        exit 1
fi

if [ ! -x /usr/bin/jq ]
then
        /bin/echo "Error: /usr/bin/jq not found or not executable." >&2
        exit 1
fi

set +e
response="$("${list_script}" "${REGION}")"
list_status="$?"
set -e

if [ "${list_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(printf '%s\n' "${response}" | /usr/bin/jq -r --arg search "${server_type}" '.[] | select((.label // "") | contains($search)) | .id')"

        if [ -z "${output}" ]
        then
                /bin/echo "Error: No matching server instance found for server type ${server_type}." >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "Error: Failed to retrieve Linode instance inventory for region '${REGION}'." >&2
        exit 1
fi

exit 0

