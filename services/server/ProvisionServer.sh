#!/bin/sh 
###################################################################################
# @file        ProvisionServer.sh
# @brief       Orchestrates the metadata preparation and triggers provider-specific instance deployment.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script gathers environment configuration data (cloudhost, region, 
#              OS configurations, firewalls, and credentials), serializes the cloud-init 
#              payload into base64 format, resolves potential snapshot restorations, 
#              and passes the consolidated parameters down to the active provider's 
#              underlying orchestration creation subsystem script.
#
# @param       $1  [Required] The targeted server hardware size plan / tier.
# @param       $2  [Required] The human-readable label/hostname assigned to the server.
# @param       $3  [Required] The structural type or architecture category of the machine.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - ${HOME}/utilities/config/ExtractConfigValue.sh 
#              - ${HOME}/services/server/GetOperatingSystemVersion.sh distribution matching software.
#              - ${HOME}/initialisation/cloud-init/InitialiseCloudConfig.sh initialization driver.
#              - ${HOME}/services/security/firewall/ConfigureNativeFirewall.sh framework security orchestrator.
#
# @security    
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Runtime options consolidated and server provisioner launched successfully.
# @exit        1  Failure: Missing positional arguments, unreadable configurations, or failure 
#                 encountered executing down-stack orchestration tooling.
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

# 1. Check for all 3 arguments safely
if [ -z "$1" ] || [ -z "$2" ]
then
        /bin/echo "Error: 2 Server arguments are required."
        /bin/echo "Usage: $0 <server_size> <server_name>"
        exit 1
fi

server_size="$1"
server_name="$2"

set +e
CLOUDHOST="$(${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST')"
WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
ACTIVE_FIREWALLS="$(${HOME}/utilities/config/ExtractConfigValue.sh 'ACTIVEFIREWALLS')"
BUILD_FROM_SNAPSHOT="$(${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDFROMSNAPSHOT')"
OS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'OSCHOICE')"
set -e

${HOME}/autoscaler/InitialiseCloudInit.sh

yaml_path="${HOME}/runtime/cloud-init/webserver.yaml"
if [ -f "${yaml_path}" ]
then
        user_data_path="${yaml_path}" 
else
        /bin/echo "Cloud config file not found" >&2
        exit 1
fi

/bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${user_data}

SNAPSHOT_ID=""
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        SNAPSHOT_ID="`${HOME}/utilities/config/ExtractConfigValue.sh 'SNAPSHOTID'`"
fi

image="${OS_CHOICE}"
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ "${SNAPSHOT_ID}" != "" ] )
then
        image="${SNAPSHOT_ID}"
fi


firewall_id=""
if [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ]
then
        set +e
        firewall_id="$("${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh" "adt-webserver" 2>/dev/null | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print $NF}')"
        set -e
fi

if [ -z "${firewall_id}" ]
then
        firewall_id="-1"
fi

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/ProvisionServer.sh"

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

#export EMERGENCY_PASSWORD="${emergency_password}"

set +e
"${script_path}" "${REGION}" "${image}" "${server_size}" "${server_name}" "${user_data_path}" "${firewall_id}" "${snapshot_id}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
        /bin/echo "Error: ProvisionServer.sh failed with exit code $exit_code" >&2
        exit $exit_code
fi

exit 0
