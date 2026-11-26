#!/bin/sh
#: Name:        GetRecordID.sh
#: Purpose:     Routes DNS record ID retrieval requests to the active DNS provider backend script.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       GetRecordID.sh <website_url> <ip>
#:              GetRecordID.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target website Fully Qualified Domain Name (FQDN)
#:   $2         [Required] Destination node IPv4 or IPv6 target address
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/dns/<DNSCHOICE>/GetRecordID.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          DNS record ID retrieval routed and executed cleanly
#:   1          Missing /home/homedir.dat, missing arguments, missing DNSCHOICE, or backend failure
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
# along with The Wintersys Agile Deployment Toolkit.  If not, see <http://gnu.org>.
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

# Resolve HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] 
then
        /bin/echo "Error: 2 arguments are required." >&2
        /bin/echo "Usage: $0 <website_url> <ip>" >&2
        exit 1
fi

website_url="${1}"
ip="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: DNS_CHOICE not set" >&2
        exit 1
fi

script_path="${HOME}/services/dns/${DNS_CHOICE}/GetRecordID.sh"

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

set +e
"${script_path}" "${website_url}" "${ip}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: GetRecordID.sh failed with exit code ${exit_code}" >&2
        exit "${exit_code}"
fi

exit 0

