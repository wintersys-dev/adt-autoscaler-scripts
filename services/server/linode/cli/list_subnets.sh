#!/bin/sh
#: Name:        list_subnets.sh
#: Purpose:     Lists all subnets associated with a specific Linode VPC network via linode-cli.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       list_subnets.sh <vpc_id>
#:              list_subnets.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Unique numeric identifier of the target Linode VPC network
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - /usr/local/bin/linode-cli
#:   - External binaries: cat, echo, printf, grep, cut
#:
#: Exit Codes:
#:   0          VPC subnets JSON array printed to stdout
#:   1          Missing /home/homedir.dat, invalid VPC ID, missing TOKEN/binaries, or CLI failure
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
        /bin/echo "Error: VPC ID argument is required." >&2
        /bin/echo "Usage: ${0} <vpc_id>" >&2
        exit 1
fi

vpc_id="${1}"

if ! printf '%s\n' "${vpc_id}" | /usr/bin/grep -Eq '^[0-9]+$'
then
        /bin/echo "Error: Invalid numeric Linode VPC ID '${vpc_id}'." >&2
        exit 1
fi

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
TOKEN="$("${extract_script}" 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (TOKEN)." >&2
        exit 1
fi

if [ ! -x /usr/local/bin/linode-cli ]
then
        /bin/echo "Error: /usr/local/bin/linode-cli not found or not executable." >&2
        exit 1
fi

trap 'unset LINODE_CLI_TOKEN' EXIT INT TERM
export LINODE_CLI_TOKEN="${TOKEN}"

set +e
/usr/local/bin/linode-cli --no-defaults --json vpcs subnets-list "${vpc_id}"
exit_code="$?"
set -e

unset LINODE_CLI_TOKEN
trap - EXIT INT TERM

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli vpcs subnets-list failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

