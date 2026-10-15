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

domainurl="`/bin/echo ${2} | /usr/bin/cut -d'.' -f2-`"
subdomain="`/bin/echo ${2} | /usr/bin/awk -F'.' '{print $1}'`"
ip="${3}"
authkey="${5}"
dns="${6}"


        /usr/bin/exo dns show ${domainurl}  --config /root/.config/exoscale/dns-exoscale.toml -O json | /usr/bin/jq -r '.[] | select (.content == "'${ip}'").id'
        #Alternative
        #/usr/bin/curl  -H "X-DNS-Token: ${authkey}" -H 'Accept: application/json' https://api.exoscale.com/dns/v1/domains/${domainurl}/records | /usr/bin/jq --arg tmp_subdomain "${subdomain}" --arg tmp_content "${ip}" '.[].record | select (.name == $tmp_subdomain and .content == $tmp_content ) | .id'
