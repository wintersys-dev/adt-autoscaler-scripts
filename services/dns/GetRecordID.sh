#!/bin/sh
###################################################################################
# @file        GetRecordID.sh
# @brief       Routes DNS record ID retrieval requests using the standalone environment layout.
# @author      Peter Winter
# @date        10/11/2026
# @version     1.0
#
# @details     This script reads a localized base directory to resolve standalone utilities,
#              evaluates website URLs, IP targets, and authority states, extracts active
#              configurations, and hands off the parameters to specific backend record ID scripts.
#
# @param       $1  [Required] The target website Fully Qualified Domain Name or URL string.
# @param       $2  [Required] The destination tracking node IPv4/IPv6 target address.
#
# @env         HOME                Path to the stand-alone environment framework directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active base home path.
#              - ExtractConfigValue.sh configuration variable extraction utility.
#              - external dependencies: cat, echo, awk, tee, test
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Protects layout evaluation chains from unexpected multi-parameter expansions.
#
# @exit        0  Success: Underlying script executed cleanly and returned code 0.
# @exit        1  Failure: Missing context paths, configuration syntax bugs, or tool failures.
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
####################################################################################
set -e

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

DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"

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

