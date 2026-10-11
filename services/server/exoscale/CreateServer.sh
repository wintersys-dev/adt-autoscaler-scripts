#!/bin/sh
######################################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script spins up a machine of the specified size, name and so on on our chosen provider
#######################################################################################################
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
#######################################################################################################
#######################################################################################################
#set -x

export HOME="`/bin/cat /home/homedir.dat`"

server_size="${1}"
server_name="${2}"

CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
BUILDOS_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOSVERSION'`"
REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
DDOS_PROTECTION="`${HOME}/utilities/config/ExtractConfigValue.sh 'ENABLEDDOSPROTECTION'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
VPC_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCNAME'`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
ACTIVE_FIREWALL="`${HOME}/utilities/config/ExtractConfigValue.sh 'ACTIVEFIREWALLS'`"
BUILD_FROM_SNAPSHOT="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDFROMSNAPSHOT'`"
OS_CHOICE="`${HOME}/services/server/GetOperatingSystemVersion.sh`"

SNAPSHOT_ID=""
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
	SNAPSHOT_ID="`${HOME}/utilities/config/ExtractConfigValue.sh 'SNAPSHOTID'`"
fi

	template_visibility=" --template-visibility public "

	/bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${HOME}/runtime/cloud-init/webserver.yaml
	cloud_config="${HOME}/runtime/cloud-init/webserver.yaml"

	if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ "${SNAPSHOT_ID}" != "" ] )
	then
		OS_CHOICE="${SNAPSHOT_ID}"
		template_visibility="--template-visibility private"
	fi
 
 	user_data="--cloud-init ${cloud_config}"

	firewall=""

	if ( [ "${ACTIVE_FIREWALL}" = "2" ] || [ "${ACTIVE_FIREWALL}" = "3" ] )
	then
		firewall="--security-group adt-webserver-${BUILD_IDENTIFIER} "
	fi

	/usr/bin/exo compute instance create "${server_name}" --instance-type standard.${server_size}  ${firewall} --template "${OS_CHOICE}" ${template_visibility} --zone ${REGION} ${user_data}

	if ( [ "`/usr/bin/exo compute private-network list -O json | /usr/bin/jq -r '.[] | select (.name == "adt_private_net_'${REGION}'").id'`" = "" ] )
	then
		/usr/bin/exo compute private-network create adt_private_net_${REGION} --zone ${REGION} --start-ip 10.0.0.20 --end-ip 10.0.0.200 --netmask 255.255.255.0
	fi
	/usr/bin/exo compute instance private-network attach  ${server_name} adt_private_net_${REGION} --zone ${REGION}

