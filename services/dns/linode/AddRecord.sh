#!/bin/sh
#: Name:        AddRecord.sh
#: Purpose:     Provisions a new dynamic A-record entry within the Linode DNS provider backend.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       AddRecord.sh <fqdn> <target_ip>
#:              AddRecord.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Fully Qualified Domain Name (e.g., "://domain.com")
#:   $2         [Required] Target IPv4 address destination tracking node
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/dns/linode/<ORCHESTRATION_TOOL>/get_domains.sh
#:   - ${HOME}/services/dns/linode/<ORCHESTRATION_TOOL>/create_record.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Target DNS A-record successfully provisioned and verified
#:   1          Missing /home/homedir.dat, missing arguments, missing domain ID, or API failure
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Fully Qualified Domain Name and target IP parameters are required." >&2
        /bin/echo "Usage: $0 <fqdn> <target_ip>" >&2
        exit 1
fi

sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
ip="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

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

set +e
domain_json="$(${HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        /bin/echo "Failed to query cluster domain management catalog or network timeout occurred." >&2
        exit 1
fi

domain_id=$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain == $dom) | .id // empty' 2>/dev/null)

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        exit 1
fi

json_payload="$(/bin/cat <<EOF
{
  "type": "A",
  "name": "${sub_domain}",
  "target": "${ip}",
  "ttl_sec": 60
}
EOF
)"

set +e
record_response="$(${HOME}/services/dns/linode/${orchestration_tool}/create_record.sh "${domain_id}" "${json_payload}")"
record_exit_code="$?"
set -e

if [ "${record_exit_code}" -ne 0 ] 
then
        /bin/echo "Failed to add record to DNS system (Network/Curl infrastructure execution error)." >&2
        exit 1
fi

if /bin/echo "${record_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        record_err_msg="$(/bin/echo "${record_response}" | /usr/bin/jq -r '.errors[0].reason // "Unknown DNS payload entry validation error."')"
        /bin/echo "Failed to add record to DNS system. Cloud Provider Reason: ${record_err_msg}" >&2
        exit 1
fi

/bin/echo "DNS record successfully added: ${sub_domain}.${domain_url} -> ${ip} [TTL: 60s]"
exit 0
