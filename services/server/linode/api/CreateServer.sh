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
TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN'`"
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

if ( [ -f ${HOME}/.ssh/EMERGENCY_PASSWORD ] )
then
	emergency_password="`/bin/cat ${HOME}/.ssh/EMERGENCY_PASSWORD`"
fi

vpc_id="`/usr/local/bin/linode-cli vpcs list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`"
subnet_id="`/usr/local/bin/linode-cli vpcs subnets-list ${vpc_id} --no-defaults --json | /usr/bin/jq -r '.[] | select (.label == "adt-subnet").id'`"

/bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${HOME}/runtime/cloud-init/webserver.yaml
cloud_config="`/bin/cat ${HOME}/runtime/cloud-init/webserver.yaml | /usr/bin/base64 -w 0`"

image="--image ${OS_CHOICE}"
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ "${SNAPSHOT_ID}" != "" ] )
then
	image="--image ${SNAPSHOT_ID}"
fi
 
user_data="--metadata.user_data ${cloud_config}"

firewall_id="`curl -s -X GET "https://linode.com" -H "Authorization: Bearer $TOKEN" | jq -r '.data[] | select(.label == "adt-webserver-'"${BUILD_IDENTIFIER}"'").id'`"

firewall_active=""
if ( [ "${ACTIVE_FIREWALL}" = "2" ] || [ "${ACTIVE_FIREWALL}" = "3" ] )
then
        firewall_active='"firewall_id": '${firewall_id}', '
fi
 
/usr/bin/curl -X POST "https://api.linode.com/v4/linode/instances" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${REGION}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ {  '"${firewall_active}"' "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }'

