#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : Add a an IP address for the given domain name
######################################################################################
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

website_url="${1}"
ip="${2}"

HOME="`/bin/cat /home/homedir.dat`"
DNS_USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSUSERNAME'`"
DNS_SECURITY_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"
DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

zone_name="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2-`"
zone_id="`${HOME}/services/dns/GetZoneID.sh "${zone_name}"`"

if ( [ "$?" ! = "0" ] )
then
        /bin/echo "Failed to get zone_id from DNS system"
        exit 1
fi

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        /bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" --header "Content-Type: application/json" --data '{"type":"A","name":"'${website_url}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
else
        auth_key="${DNS_SECURITY_KEY}"
        /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" --data '{"type":"A","name":"'${website_url}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
fi

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to Add record to for url ${website_url} with ip address ${ip} to the DNS system"
        exit 1
fi
