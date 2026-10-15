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

#DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"


#auth_key="${3}"
subdomain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"
domainurl="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
ip="${2}"

linode_config_file="/root/.config/dns-linode-cli"
        
if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
then
	linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
fi
                        
export LINODE_CLI_CONFIG=${linode_config_file}
	
domain_id="`/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id'`"

if ( [ "$?" != "0" ] || [ "${domain_id}" = "" ] )
then
	/bin/echo "Domain ID not successfully obtained"
	exit 1
fi
    
if ( [ "`/usr/local/bin/linode-cli domains records-list ${domain_id} --no-defaults --json | /usr/bin/jq -r '.[] | select (.target == "'${ip}'").id`" = "" ] )
do
	/usr/local/bin/linode-cli domains records-create ${domain_id} --type A --name ${subdomain} --target ${ip} --ttl_sec 60 --no-defaults 
	if ( [ "$?" != "0" ] || [ "${domain_id}" = "" ] )
	then
		/bin/echo "DNS Record not successfully created"
		exit 1
	fi
done

unset LINODE_CLI_CONFIG
 
