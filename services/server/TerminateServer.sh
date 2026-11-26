#!/bin/sh
#: Name:        TerminateServer.sh
#: Purpose:     Routes server instance termination by public IPv4 address to the active cloud provider driver.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       TerminateServer.sh <server_ip>
#:              TerminateServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Public IPv4 address of the target server instance to destroy
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/server/<cloudhost>/TerminateServer.sh
#:   - External binaries: cat, echo, printf, grep, cut
#:
#: Exit Codes:
#:   0          Server instance terminated cleanly by provider driver
#:   1          Missing /home/homedir.dat, invalid IP argument, missing driver, or provider termination failure
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

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
CLOUDHOST="$("${extract_script}" 'CLOUDHOST')"
set -e

if [ -z "${CLOUDHOST}" ]
then
        /bin/echo "Error: Failed to retrieve CLOUDHOST configuration value." >&2
        exit 1
fi

script_path="${HOME}/services/server/${CLOUDHOST}/TerminateServer.sh"

if [ ! -f "${script_path}" ]
then
        /bin/echo "Error: Script not found at ${script_path}" >&2
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        /bin/echo "Error: Script at ${script_path} is not executable." >&2
        exit 1
fi

exec "${script_path}" "${server_ip}"




