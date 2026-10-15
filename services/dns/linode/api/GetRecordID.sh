#!/bin/sh
###########################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will get a record id for a given ip address for the dns provider
# we are using
###########################################################################################
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
#######################################################################################
#######################################################################################
#set -x
set -e

domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
sub_domain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"
ip="${2}"

linode_config_file="/root/.config/dns-linode-cli"

if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
then
        linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
fi

export LINODE_CLI_CONFIG=${linode_config_file}
domain_id="`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$domain_url'")).id'`"
if ( [ "$?" != "0" ] || [ "${domain_id}" = "" ] )
then
        /bin/echo "DNS domain ID not successfully obtained"
        unset LINODE_CLI_CONFIG
        exit  1
fi

curl -s "https://api.linode.com/v4/domains/${domain_id}/records" -H "Authorization: Bearer $TOKEN" | jq --arg sub "${sub_domain}" -r '.data[] | select(.name == $sub) | .id'
if ( [ "$?" != "0" ] )
then
        /bin/echo "DNS record could not be listed"
        unset LINODE_CLI_CONFIG
        exit  1
fi

unset LINODE_CLI_CONFIG
