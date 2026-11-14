#!/bin/sh
#set -x
set -e

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
        /bin/echo "Error: Website URL and target IP address parameters are required." >&2
        /bin/echo "Usage: $0 <website_url> <target_ip>" >&2
        exit 1
fi

website_url="${1}"
ip="${2}"

# Extract structural configuration contexts securely via modern subshells
set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

# Parse apex zone identifier safely
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"

# Intercept and capture zone ID configurations cleanly
zone_id="$("${HOME}/services/dns/GetZoneID.sh" "${zone_name}")"


if [ -z "${DNS_CHOICE}" ] 
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

if [ ! -d "${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi



# Assemble raw JSON transaction parameters block defensively to resist string injection threats
json_payload="$(/bin/cat <<EOF
{
  "type": "A",
  "name": "${website_url}",
  "content": "${ip}",
  "ttl": 120,
  "proxied": true
}
EOF
)"

set +e
response="$(${HOME}/services/dns/cloudflare/${orchestration_tool}/add_record.sh "${zone_id}" "${json_payload}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Failed to add record to DNS system (Network/Curl infrastructure execution error)." >&2
        exit 1
fi

# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare validation error details."')"
        /bin/echo "Failed to Add record for url ${website_url} to the DNS system. Cloud Provider Reason: ${err_msg}" >&2
        exit 1
fi

/bin/echo "Cloudflare DNS A-record successfully provisioned: ${website_url} -> ${ip} [Proxied: True, TTL: 120s]"
exit 0
