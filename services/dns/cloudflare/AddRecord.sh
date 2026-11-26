#!/bin/sh
#: Name:        AddRecord.sh
#: Purpose:     Provisions a new proxied DNS A-record entry within the Cloudflare DNS provider backend.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       AddRecord.sh <website_url> <target_ip>
#:              AddRecord.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target website Fully Qualified Domain Name (e.g., "://domain.com")
#:   $2         [Required] Destination node IPv4 address
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/dns/GetZoneID.sh
#:   - ${HOME}/services/dns/cloudflare/<ORCHESTRATION_TOOL>/add_record.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Cloudflare DNS A-record successfully provisioned and verified
#:   1          Missing /home/homedir.dat, missing arguments, missing zone ID, or API failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

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

# Extract DNS provider choice
set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (DNSCHOICE)." >&2
        exit 1
fi

# Parse apex zone identifier and resolve Cloudflare zone ID
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"
zone_id="$("${HOME}/services/dns/GetZoneID.sh" "${zone_name}")"

if [ -z "${zone_id}" ]
then
        /bin/echo "Error: Failed to resolve Cloudflare Zone ID for '${zone_name}'." >&2
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

# Assemble JSON payload for Cloudflare DNS A-record creation
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
response="$("${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/add_record.sh" "${zone_id}" "${json_payload}")"
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

