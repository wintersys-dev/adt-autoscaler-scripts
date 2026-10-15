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

subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domainurl="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"


        record_id="`/usr/bin/vultr dns record list ${domainurl} --config /root/.dns-vultr-cli.yaml -o json | /usr/bin/jq -r '.records[] | select (.data == "'${ip}'").id'`"
        if ( [ "${record_id}" = "" ] )
        then
                /usr/bin/vultr dns record delete ${domainurl} ${record_id} --config /root/.dns-vultr-cli.yaml 
        fi
