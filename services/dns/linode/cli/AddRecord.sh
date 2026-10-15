#!/bin/sh
##################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will add an ip address (A Record) to the DNS provider
##################################################################################
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

${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/AddRecord.sh ${zone_id} ${dns_username} ${dns_security_key} ${website_url} ${ip} ${dns_choice}

auth_key="${3}"

ip="${4}"

linode_config_file="/root/.config/dns-linode-cli"
        
if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
then
	linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
fi
                        
export LINODE_CLI_CONFIG=${linode_config_file}
	
domain_id="`/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id'`"
    
count="0"
while ( [ "${count}" -lt "5" ] && [ "`/usr/local/bin/linode-cli domains records-list ${domain_id} --no-defaults --json | /usr/bin/jq -r '.[] | select (.target == "'${ip}'").id'`" = "" ] )
do
	count="`/usr/bin/expr ${count} + 1`"
	/usr/local/bin/linode-cli domains records-create ${domain_id} --type A --name ${subdomain} --target ${ip} --ttl_sec 60 --no-defaults 
done

unset LINODE_CLI_CONFIG
 
