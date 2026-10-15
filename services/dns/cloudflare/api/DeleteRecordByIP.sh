zoneid="${1}"
email="${2}"
credentials="${3}"
websiteurl="${4}"
ip="${5}"
dns="${6}"

if ( [ "${dns}" = "cloudflare" ] )
then
        if ( [ "`/bin/echo ${credentials} | /bin/grep ':::'`" != "" ] )
        then
                api_token="`/bin/echo ${credentials} | /usr/bin/awk -F':::' '{print $2}'`"
                record_id="`/usr/bin/curl "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
                /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${record_id}" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json"
        else
                authkey="${credentials}"
                record_id="`/usr/bin/curl "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${authkey}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[]  | select (.content == "'${ip}'").id'`"
                /usr/bin/curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${record_id}" -H "X-Auth-Email: ${email}"  -H "X-Auth-Key: ${authkey}" -H "Content-Type: application/json"
        fi
fi
