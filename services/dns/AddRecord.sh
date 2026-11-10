#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This will add a record to the DNS system given the website url
# and the ip address to add
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
####################################################################################
#set -x
set -e


HOME="$(/bin/cat /home/homedir.dat)"

if [ "${1}" = "" ] || [ "${2}" = "" ] 
then
        /bin/echo "Error: 2 arguments are required."
        /bin/echo "Usage: $0 <website_url> <ip>"
        exit 1
fi

website_url="${1}"
ip="${2}"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ] 
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if  [ "${orchestration_tool}" = "" ] 
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_tool}" 
        exit 1
fi

if  [ ! -d ${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool} ] 
then
        orchestration_tool="api"
fi

script_path="${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/AddRecord.sh"

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


"${script_path}" "${website_url}" "${ip}"

exit_code=$?

if [ ${exit_code} -ne 0 ]
then
        /bin/echo "Error: AddRecord.sh failed with exit code $exit_code"
        exit $exit_code
fi
