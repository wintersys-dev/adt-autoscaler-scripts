#!/bin/sh
#set -x
set -e

# Resolve HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: website_url and ip parameters are required." >&2
        /bin/echo "Usage: $0 <website_url> <ip>" >&2
        exit 1
fi

# Strip any accidental whitespace/newlines from parameters to prevent curl exit code 3
website_url="$(/bin/echo "${1}" | /usr/bin/tr -d '[:space:]')"
ip="$(/bin/echo "${2}" | /usr/bin/tr -d '[:space:]')"

if [ -z "${website_url}" ] || [ -z "${ip}" ]
then
        /bin/echo "Error: website_url or ip is empty after whitespace removal." >&2
        exit 1
fi

DNS_USERNAME="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSUSERNAME')"
DNS_SECURITY_KEY="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSSECURITYKEY')"

zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"

set +e
zone_id="$("${HOME}/services/dns/GetZoneID.sh" "${zone_name}")"
ZONE_EXIT=$?
set -e

zone_id="$(/bin/echo "${zone_id}" | /usr/bin/tr -d '[:space:]')"

if [ "${ZONE_EXIT}" -ne 0 ] || [ -z "${zone_id}" ]
then
        /bin/echo "Error: Failed to get zone_id for domain ${zone_name} from DNS system." >&2
        exit 1
fi

API_URL="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}&content=${ip}"

# Build authentication headers and execute request
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        api_token="${DNS_SECURITY_KEY#*:::}"
        RESPONSE="$(/bin/echo "Authorization: Bearer ${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_URL}" -H "Content-Type: application/json" 2>&1)"
else
        RESPONSE="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_URL}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" 2>&1)"
fi
CURL_EXIT=$?
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        /bin/echo "Error: curl failed with exit code ${CURL_EXIT} while fetching record IDs for ${website_url} (${ip})." >&2
        /bin/echo "Detail: ${RESPONSE}" >&2
        exit 1
fi

# Extract HTTP status code and response body using strict POSIX filtering
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate the API response code
case "${HTTP_CODE}" in
        200|201)
                record_ids="$(/bin/echo "${RESPONSE_BODY}" | /usr/bin/jq -r '.result[].id // empty')"
                if [ -z "${record_ids}" ]
                then
                        /bin/echo "Error: No active A-records found matching name '${website_url}' and IP '${ip}' inside zone '${zone_id}'." >&2
                        exit 1
                fi
                /bin/echo "${record_ids}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check website_url (${website_url}), ip (${ip}), or zone_id (${zone_id}) parameters." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Credentials lack permission to list DNS records for this zone." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Verify that zone_id (${zone_id}) exists." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Cloudflare API or Upstream Server Exception." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE:-UNKNOWN}: Unexpected response from Cloudflare API." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac



