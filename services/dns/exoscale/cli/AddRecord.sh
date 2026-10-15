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

authkey="${3}"
subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domainurl="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"

        count="0"
        id="`/usr/bin/exo dns list --config /root/.config/exoscale/dns-exoscale.toml -O json | /usr/bin/jq -r '.[] | select (.name == "'${domainurl}'").id'`"

        if ( [ "${id}" != "" ] )
        then
                while ( [ "${count}" -lt "5" ] && [ "`/usr/bin/exo dns show ${id} --config /root/.config/exoscale/dns-exoscale.toml -O json | /usr/bin/jq -r '.[] | select (.content == "'${ip}'").id'`" = "" ] )
                do
                        count="`/usr/bin/expr ${count} + 1`"
                        /usr/bin/exo dns add A ${domainurl} -a ${ip} -n ${subdomain} -t 60 --config /root/.config/exoscale/dns-exoscale.toml
                done
        fi

        if ( [ "${count}" = "5" ] || [ "${id}" = "" ] )
        then
                ${HOME}/services/email/SendEmail.sh "FAILED TO ADD IP ADDRESS TO DNS SYSTEM" "IP address (${ip}) for domain ${domainurl}) could not be added to the DNS system" "ERROR"
        fi
