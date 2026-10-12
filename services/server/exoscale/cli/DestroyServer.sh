#!/bin/sh
#######################################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script destroys a machine based on ip address and cleans up after it is destroyed
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

server_ip="${1}"
private_server_ip="`${HOME}/services/server/GetServerPrivateIPAddressByIP.sh ${server_ip}`"

	if ( [ "${server_ip}" != "" ] )
	then
		zone="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
		server_name="`${HOME}/services/server/GetServerName.sh ${server_ip}`"
		/bin/echo "Y" | /usr/bin/exo compute instance delete ${server_name} --zone ${zone} 

		${HOME}/services/datastore/config/wrapper/DeleteFromDatastore.sh "config"  "webserverips/${private_server_ip}"
		${HOME}/services/datastore/config/wrapper/DeleteFromDatastore.sh "config"  "webserverpublicips/${server_ip}"

		if ( [ -f ${HOME}/runtime/POTENTIAL_STALLED_BUILD:${server_ip} ] )
		then
			/bin/rm ${HOME}/runtime/POTENTIAL_STALLED_BUILD:${server_ip}
		fi
	fi

