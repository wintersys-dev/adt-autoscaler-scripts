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

if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
    status "Error: Two arguments are required."
    status "Usage: $0 <website_url> <ip>" 
    exit 1
fi

domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
sub_domain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"
ip="${2}"

TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"

domain_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/domains" | jq -r '.data[] | select(.domain | contains("'$domain_url'")).id'`"
if ( [ "$?" != "0" ] || [ "${domain_id}" = "" ] )
then
        /bin/echo "DNS domain ID not successfully obtained"
        exit  1
fi

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/domains/${domain_id}/records" | jq --arg sub "${sub_domain}" -r '.data[] | select(.name == $sub) | .id'
if ( [ "$?" != "0" ] )
then
        /bin/echo "DNS record could not be listed"
        exit  1
fi

