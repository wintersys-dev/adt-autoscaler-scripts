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
if [ -z "${1}" ]
then
        /bin/echo "Error: zone_name parameter is required." >&2
        /bin/echo "Usage: $0 <zone_name>" >&2
        exit 1
fi

# Strip any accidental whitespace/newlines from zone_name to prevent curl exit code 3
zone_name="$(/bin/echo "${1}" | /usr/bin/tr -d '[:space:]')"

if [ -z "${zone_name}" ]
then
        /bin/echo "Error: zone_name is empty after whitespace removal." >&2
        exit 1
fi

DNS_USERNAME="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSUSERNAME')"
DNS_SECURITY_KEY="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'DNSSECURITYKEY')"

API_URL="https://api.cloudflare.com/client/v4/zones?name=${zone_name}" 

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
        /bin/echo "Error: curl failed with exit code ${CURL_EXIT} while querying zone ID for ${zone_name}." >&2
        /bin/echo "Detail: ${RESPONSE}" >&2
        exit 1
fi

# Extract HTTP status code and response body using strict POSIX filtering
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate the API response code
case "${HTTP_CODE}" in
        200|201)
                zone_id="$(/bin/echo "${RESPONSE_BODY}" | /usr/bin/jq -r '.result[].id // empty')"
                if [ -z "${zone_id}" ]
                then
                        /bin/echo "Error: No active zones found matching name '${zone_name}' in the DNS system." >&2
                        exit 1
                fi
                /bin/echo "${zone_id}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check zone_name (${zone_name}) parameter syntax." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Credentials lack permission to list zones." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. The requested Cloudflare API endpoint could not be found." >&2
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

