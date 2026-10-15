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


	#Make damn sure that the DNS record gets added to the DNS system
	count="0"
	while ( [ "${count}" -lt "5" ] && [ "`/usr/bin/vultr dns record list ${domainurl} --config /root/.dns-vultr-cli.yaml -o json | /usr/bin/jq -r '.records[] | select (.data == "'${ip}'").id'`" = "" ] )
	do
		count="`/usr/bin/expr ${count} + 1`"
		/usr/bin/vultr dns record create ${domainurl} -n ${subdomain} -t A -d "${ip}" --priority=10 --ttl=60 --config /root/.dns-vultr-cli.yaml 
	done

 	if ( [ "${count}" = "5" ] )
  	then
		${HOME}/services/email/SendEmail.sh "FAILED TO ADD IP ADDRESS TO DNS SYSTEM" "IP address (${ip}) for domain ${domainurl}) could not be added to the DNS system" "ERROR"
	fi
