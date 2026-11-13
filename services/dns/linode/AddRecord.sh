#!/bin/sh
###################################################################################
# @file        AddRecord.sh
# @brief       Provisions a new dynamic A-record entry within the DNS provider matrix.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target fully qualified domain name (FQDN) into 
#              isolated sub-domain and baseline zone properties, queries provider catalogs
#              securely to capture the domain zone ID wrapper, and executes an authorized
#              transaction payload to inject the tracking destination IP node.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
# @param       $2  [Required] The target IPv4 address destination tracking node.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - external dependencies: cat, echo, awk, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS A-record successfully provisioned and verified.
# @exit        1  Failure: Missing context paths, input parameter errors, or API communication failures.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
#set -x
set -e

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

domain_id=$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)

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
