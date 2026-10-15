zoneid="${1}"
websiteurl="${2}"
ip="${3}"
email="${4}"
credentials="${5}"
dns="${6}"

if ( [ "${dns}" = "cloudflare" ] )
then
        if ( [ "`/bin/echo ${credentials} | /usr/bin/awk -F':::' '{print $2}'`" != "" ] )
        then
                api_token="`/bin/echo ${credentials} | /usr/bin/awk -F':::' '{print $2}'`"
                /usr/bin/curl -X GET "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records?type=A&name=${websiteurl}&content=${ip}&page=1&per_page=20&order=type&direction=desc&match=all" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" | /usr/bin/jq -r '.result[].id'
        else
                authkey="${credentials}"
                /usr/bin/curl -X GET "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records?type=A&name=${websiteurl}&content=${ip}&page=1&per_page=20&order=type&direction=desc&match=all" -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${authkey}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].id'
        fi
fi
