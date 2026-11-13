zone_name="${1}"

HOME="`/bin/cat /home/homedir.dat`"

DNS_USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSUSERNAME'`"
DNS_SECURITY_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"


if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}"  -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].id'
else
        auth_key="${DNS_SECURITY_KEY}"
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${auth_key}"  -H "Content-Type: application/json" | /usr/bin/jq -r '.result[]? | .id'

fi
