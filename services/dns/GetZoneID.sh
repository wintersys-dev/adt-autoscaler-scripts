#!/bin/sh
###################################################################################
# @file        GetZoneID.sh
# @brief       Routes DNS zone ID retrieval requests to specialized backend scripts.
# @author      Peter Winter
# @date        10/11/2026
# @version     1.0
#
# @details     This script evaluates a target zone name to determine the designated
#              DNS provider context. It maps the active deployment strategy against
#              centralized hardware and software configurations before handing off
#              execution to target providers to fetch the matching zone tracking ID.
#
# @param       $1  [Required] The target DNS zone name string (e.g., "domain.com").
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - external dependencies: cat, awk, test
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Protects layout evaluation chains from unexpected multi-parameter expansions.
#
# @exit        0  Success: Underlying script executed cleanly and returned code 0 or script was skipped.
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
#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ]
then
        /bin/echo "Error: 1 argument is required."  >&2
        /bin/echo "Usage: $0 <zone_name>"  >&2
        exit 1
fi

zone_name="${1}"

DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"

script_path="${BUILD_HOME}/services/dns/${DNS_CHOICE}/GetZoneID.sh"

if [ -f "${script_path}" ]
then
        if [ ! -x "${script_path}" ]
        then
                /bin/echo "Error: Script at ${script_path} is not executable." >&2
                exit 1
        fi


        set +e
        "${script_path}" "${zone_name}"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -ne 0 ] 
        then
                /bin/echo "Error: GetZoneID.sh failed with exit code ${exit_code}" >&2
                exit "${exit_code}"
        fi
fi

exit 0


