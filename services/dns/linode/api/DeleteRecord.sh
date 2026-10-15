#!/bin/sh
#######################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will delete a DNS A record using the 'record id' to delete it
########################################################################################
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
#####################################################################################
#####################################################################################
#set -x
set -e

if ( [ "${1}" = "" ] )
then
    status "Error: One argument is required."
    status "Usage: $0 <record_id>" 
    exit 1
fi

HOME="`/bin/cat /home/homedir.dat`"

record_id="${1}"
domain_url="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL' | /usr/bin/cut -d'.' -f2-`"

TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"

domain_id="`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$domain_url'")).id'`"
curl -s -X DELETE -H "Authorization: Bearer $TOKEN"  "https://api.linode.com/v4/domains/${domain_id}/records/${record_id}"

