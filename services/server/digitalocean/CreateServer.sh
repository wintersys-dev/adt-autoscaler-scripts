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


	vpc_id="`/usr/local/bin/doctl vpcs list -o json | /usr/bin/jq -r '.[] | select (.region == "'${REGION}'") | select (.name == ("'${VPC_NAME}'")).id'`"
	firewall_id="`/usr/local/bin/doctl -o json compute firewall list | /usr/bin/jq -r '.[] | select (.name == "adt-webserver-'${BUILD_IDENTIFIER}'" ).id'`"

	/bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${HOME}/runtime/cloud-init/webserver.yaml
	cloud_config="`/bin/cat ${HOME}/runtime/cloud-init/webserver.yaml`"

	image="--image ${OS_CHOICE}"

	if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ "${SNAPSHOT_ID}" != "" ] )
	then
		image="--image ${SNAPSHOT_ID}"
	fi

 	key_id="`/usr/local/bin/doctl compute ssh-key list -o json | /usr/bin/jq '.[] | select (.name == "AGILE_TOOLKIT_PUBLIC_KEY-'${BUILD_IDENTIFIER}'").id'`" 

	webserver_id="`/usr/local/bin/doctl compute droplet create "${server_name}" -o json --size "${server_size}" ${image} --region "${REGION}" --ssh-keys "${key_id}" --vpc-uuid "${vpc_id}" --user-data "${cloud_config}" | /usr/bin/jq -r '.[].id'`"

	/bin/sleep 5

	if ( [ "${ACTIVE_FIREWALL}" = "2" ] || [ "${ACTIVE_FIREWALL}" = "3" ] )
	then
		/usr/local/bin/doctl compute firewall add-droplets ${firewall_id} --droplet-ids ${webserver_id}
	fi

