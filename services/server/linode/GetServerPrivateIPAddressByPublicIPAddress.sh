#!/bin/sh
#: Name:        GetServerPrivateIPAddressByPublicIPAddress.sh
#: Purpose:     Resolves a Linode instance's private VPC IPv4 address from its public 1:1 NAT IPv4 address.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       GetServerPrivateIPAddressByPublicIPAddress.sh <server_public_ip>
#:              GetServerPrivateIPAddressByPublicIPAddress.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target public IPv4 address of the Linode server instance
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/services/server/linode/<orchestration_tool>/get_vpc_ips.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, tr, head, jq
#:
#: Exit Codes:
#:   0          Private VPC IPv4 address resolved and printed to stdout
#:   1          Missing /home/homedir.dat, invalid IP argument, missing driver/config, or no matching VPC IP
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
        /bin/echo "Error: Server public IP address argument is required." >&2
        /bin/echo "Usage: ${0} <server_public_ip>" >&2
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

vpc_ips_script="${HOME}/services/server/linode/${orchestration_tool}/get_vpc_ips.sh"
if [ ! -x "${vpc_ips_script}" ]
then
        /bin/echo "Error: VPC IP lookup script missing or not executable at ${vpc_ips_script}" >&2
        exit 1
fi

if [ ! -x /usr/bin/jq ]
then
        /bin/echo "Error: /usr/bin/jq not found or not executable." >&2
        exit 1
fi

set +e
response="$("${vpc_ips_script}" "${REGION}")"
vpc_status="$?"
set -e

if [ "${vpc_status}" -ne 0 ] || [ -z "${response}" ]
then
        /bin/echo "Error: Failed to retrieve Linode VPC IP inventory for region '${REGION}'." >&2
        exit 1
fi

output="$(printf '%s\n' "${response}" | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select((.nat_1_1 // "") == $ip) | .address' | /usr/bin/head -n 1)"

if [ -z "${output}" ] || [ "${output}" = "null" ]
then
        /bin/echo "Error: No matching private IP address found for public IP ${server_ip}." >&2
        exit 1
fi

/bin/echo "${output}"
exit 0

