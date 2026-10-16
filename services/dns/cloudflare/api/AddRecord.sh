#!/bin/sh
#set -x

website_url="${1}"
ip="${2}"

HOME="`/bin/cat /home/homedir.dat`"
DNS_USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSUSERNAME'`"
DNS_SECURITY_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"
DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

zone_name="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2-`"
zone_id="`${HOME}/services/dns/GetZoneID.sh "${zone_name}"`"

if ( [ "${zone_id}" = "" ] )
then
        ${HOME}/services/dns/CreateZone.sh  "${website_url}"
        zone_id="`${HOME}/services/dns/GetZoneID.sh "${zone_name}"`"
fi

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" --data '{"type":"A","name":"'${website_url}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
else
        auth_key="${DNS_SECURITY_KEY}"
        /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" --data '{"type":"A","name":"'${website_url}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
fi
