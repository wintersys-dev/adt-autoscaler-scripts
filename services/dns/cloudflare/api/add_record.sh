#!/bin/sh
#set -x
set -e

# Resolve BUILD_HOME baseline layout securely
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
        /bin/echo "Error: zone_id and json_payload parameters are required." >&2
        /bin/echo "Usage: $0 <zone_id> <json_payload>" >&2
        exit 1
fi

# Strip any accidental whitespace/newlines from zone_id to prevent curl exit code 3
zone_id="$(printf '%s' "${1}" | /usr/bin/tr -d '[:space:]')"
json_payload="${2}"

if [ -z "${zone_id}" ]
then
        /bin/echo "Error: zone_id is empty after whitespace removal." >&2
        exit 1
fi

DNS_USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSUSERNAME'`"
DNS_SECURITY_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"

API_URL="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

# Build authentication headers and execute request
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        api_token="${DNS_SECURITY_KEY#*:::}"
        RESPONSE="$(/bin/echo "Authorization: Bearer ${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_URL}" --header "Content-Type: application/json" --data "${json_payload}" 2>&1)"
else
        RESPONSE="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_URL}" --header "X-Auth-Email: ${DNS_USERNAME}" --header "Content-Type: application/json" --data "${json_payload}" 2>&1)"
fi
CURL_EXIT=$?
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        /bin/echo "Error: curl failed with exit code ${CURL_EXIT}." >&2
        /bin/echo "Detail: ${RESPONSE}" >&2
        exit 1
fi

# Extract HTTP status code and response body using strict POSIX filtering
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate the API response code
case "${HTTP_CODE}" in
        200|201)
                /bin/echo '%s\n' "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check JSON payload syntax or DNS record parameters." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Credentials lack permission to modify DNS records for this zone." >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Verify that zone_id (${zone_id}) exists." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Cloudflare API or Upstream Server Exception." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE:-UNKNOWN}: Unexpected response from Cloudflare API." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
esac
