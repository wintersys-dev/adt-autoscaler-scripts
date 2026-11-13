#!/bin/sh
###################################################################################
# @file        GetRecordID.sh
# @brief       Resolves the unique DNS record identifier matching an FQDN and IP address.
# @author      Peter Winter
# @date        13/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) into
#              its zone apex domain root and sub-domain fields, resolves the active
#              orchestration tool (CLI or API), queries provider catalogs to capture
#              the parent zone ID, and filters zone record entries to output the
#              record ID matching both the sub-domain and target IP address.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "://domain.com").
# @param       $2  [Required] The target IP address to match against DNS records.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - software.dat configuration file defining the active ORCHESTRATION_TOOL.
#              - external dependencies: cat, echo, awk, cut, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Protects dynamic JSON queries from parameter injection via jq --arg.
#
# @exit        0  Success: Matching DNS record ID successfully resolved and printed.
# @exit        1  Failure: Missing context paths, input parameter errors, or lookup failures.
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
        status "Error: Fully Qualified Domain Name and target IP parameters are required." >&2
        status "Usage: $0 <fqdn> <target_ip>" >&2
        exit 1
fi

sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
target_ip="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (DNS_CHOICE)." >&2
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
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

set +e
domain_json="$("${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        /bin/echo "Failed to query domain management catalog or network timeout occurred." >&2
        exit 1
fi

err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r 'if type == "object" and .errors then (.errors | if type == "array" then first.reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${err_msg}" ]
then
        /bin/echo "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}" >&2
        exit 1
fi

set +e
domain_id="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domain_id.sh" "${domain_json}" "${domain_url}")"
set -e

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        exit 1
fi

set +e
records_json="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_record_ids.sh" "${domain_id}")"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${records_json}" ]
then
        /bin/echo "Failed to get all record IDs from the DNS system for root domain ${domain_url} and sub domain ${sub_domain}." >&2
        exit 1
fi

records_err_msg="$(/bin/echo "${records_json}" | /usr/bin/jq -r 'if type == "object" and .errors then (.errors | if type == "array" then first.reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${records_err_msg}" ]
then
        /bin/echo "Failed to look up records in the DNS system. Cloud Provider Reason: ${records_err_msg}" >&2
        exit 1
fi

# Match record ID by both subdomain name and target IP address
record_id="$(/bin/echo "${records_json}" | /usr/bin/jq -r --arg sub "${sub_domain}" --arg ip "${target_ip}" '(if type == "object" and has("data") then .data else . end)[] | select(.name == $sub and .target == $ip) | .id // empty')"

if [ -z "${record_id}" ]
then
        /bin/echo "DNS Record ID not found matching '${sub_domain}.${domain_url}' -> '${target_ip}'." >&2
        exit 1
fi

/bin/echo "${record_id}"
exit 0
