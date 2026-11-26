#!/bin/sh
#: Name:        GetServerPrivateIPAddressesMain.sh
#: Purpose:     Routes private IPv4 address discovery by server type/label to the active cloud provider driver.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPrivateIPAddressesMain.sh <server_type>
#:              GetServerPrivateIPAddressesMain.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Server type prefix or unique machine label (e.g., ws-lon1-prod)
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/server/<cloudhost>/GetServerPrivateIPAddresses.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Private IPv4 address(es) resolved and printed cleanly
#:   1          Missing /home/homedir.dat, missing argument, missing driver, or provider lookup failure
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
CLOUDHOST="$("${extract_script}" 'CLOUDHOST')"
set -e

if [ -z "${CLOUDHOST}" ]
then
        /bin/echo "Error: Failed to retrieve CLOUDHOST configuration value." >&2
        exit 1
fi

script_path="${HOME}/services/server/${CLOUDHOST}/GetServerPrivateIPAddresses.sh"

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

exec "${script_path}" "${server_type}"




