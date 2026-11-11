#!/bin/sh 
###################################################################################
# @file        GetServerName.sh
# @brief       Resolves active provider configurations and triggers label discovery by IP.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script acts as the entry orchestrator within the framework for 
#              server metadata lookup. It verifies active cloud environment states,
#              determines the downstream orchestration toolchain, validates script 
#              permissions, and hands off the target IPv4 address to find its 
#              corresponding host system name.
#
# @param       $1  [Required] The targeted public IPv4 address of the server instance.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#
# @security    
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target handoff complete and server name resolved successfully.
# @exit        1  Failure: Missing arguments, unreadable environment configurations, 
#                 or an error encountered executing downstream provider scripts.
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
#########################################################################################
#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi


# 1. Check for the required argument safely
if [ -z "$1" ]
then
    /bin/echo "Error: Server IP address argument is required." >&2
    /bin/echo "Usage: $0 <server_ip>" >&2
    exit 1
fi

server_ip="$1"

set +e
CLOUDHOST="$(${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST')"
set -e

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/GetServerName.sh"

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
"${script_path}" "${server_ip}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
    /bin/echo "Error: GetServerName.sh failed with exit code $exit_code" >&2
    exit $exit_code
fi

exit 0




