#!/bin/sh
###################################################################################
# @file        DeleteRecord.sh
# @brief       Routes DNS record deletion requests to specialized backend scripts.
# @author      Peter Winter
# @date        10/11/2026
# @version     1.0
#
# @details     This script evaluates a specific record ID, a target website URL,
#              and authority constraints to determine the designated provider context.
#              It maps the active deployment strategy against centralized hardware and
#              software configurations before handing off execution to target providers.
#
# @param       $1  [Required] The unique platform identifier of the target DNS record.
# @param       $2  [Required] The target website Fully Qualified Domain Name or URL string.
# @param       $3  [Required] Authority flag validation parameter ("yes" / "no").
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - ${HOME}/runtime/software.dat static asset properties.
#              - external dependencies: cat, awk, test
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
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
#set -x
set -e

# Resolve HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        /bin/echo "Error: 3 arguments are required."
        /bin/echo "Usage: $0 <record_id> <website_url> <auth>"
        exit 1
fi

record_id="${1}"
website_url="${2}"
auth="${3}"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" 
        exit 1
fi

if [ ! -d "${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

script_path="${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecord.sh"

if [ ! -f "${script_path}" ]
then
        /bin/echo "Error: Script not found at ${script_path}" 
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        /bin/echo "Error: Script at ${script_path} is not executable." 
        exit 1
fi

set +e
"${script_path}" "${record_id}" "${website_url}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: DeleteRecord.sh failed with exit code ${exit_code}"
        exit "${exit_code}"
fi

exit 0

