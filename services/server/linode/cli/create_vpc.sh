#!/bin/sh
#: Name:        create_vpc.sh
#: Purpose:     Provisions a Linode Virtual Private Cloud (VPC) network via linode-cli.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       create_vpc.sh <vpc_cli_flags_or_json>
#:              create_vpc.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] linode-cli vpcs create flag string or JSON specification payload
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - /usr/local/bin/linode-cli
#:   - External binaries: cat, echo, printf, grep, cut, jq
#:
#: Exit Codes:
#:   0          Linode VPC network provisioned cleanly (JSON output printed to stdout)
#:   1          Missing /home/homedir.dat, invalid argument, missing TOKEN, or linode-cli error
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
        /bin/echo "Error: VPC configuration payload argument is required." >&2
        /bin/echo "Usage: ${0} <vpc_cli_flags_or_json>" >&2
        exit 1
fi

vpc_payload="${1}"

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
case "${vpc_payload}" in
        \{*)
                if [ ! -x /usr/bin/jq ]
                then
                        /bin/echo "Error: /usr/bin/jq required to parse JSON VPC payload." >&2
                        exit 1
                fi
                vpc_label="$(printf '%s\n' "${vpc_payload}" | /usr/bin/jq -r '.label // empty')"
                vpc_region="$(printf '%s\n' "${vpc_payload}" | /usr/bin/jq -r '.region // empty')"
                sub_label="$(printf '%s\n' "${vpc_payload}" | /usr/bin/jq -r '.subnets[0].label // "adt-subnet"')"
                sub_ipv4="$(printf '%s\n' "${vpc_payload}" | /usr/bin/jq -r '.subnets[0].ipv4 // empty')"
                /usr/local/bin/linode-cli --no-defaults --json vpcs create \
                        --label "${vpc_label}" \
                        --region "${vpc_region}" \
                        --subnets.label "${sub_label}" \
                        --subnets.ipv4 "${sub_ipv4}"
                exit_code="$?"
                ;;
        *)
                eval "set -- ${vpc_payload}"
                /usr/local/bin/linode-cli --no-defaults --json vpcs create "$@"
                exit_code="$?"
                ;;
esac
set -e

unset LINODE_CLI_TOKEN
trap - EXIT INT TERM

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli vpcs create failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

/bin/echo "Success: Linode VPC instance provisioned cleanly." >&2
exit 0

