#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : Delete a record from the DNS system given its ip and its url
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

HOME="`/bin/cat /home/honedir.dat`"
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
        record_id="`/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" --header "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
        /bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" --header "Content-Type: application/json"
else
        auth_key="${DNS_SECURITY_KEY}"
        record_id="`/usr/bin/curl "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
        /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"
fi

if ( [ "$?" != "0" ] )
then
        status "Failed to delete record from DNS system with ip: ${ip} and url: ${website_url}"
        exit 1
fi
