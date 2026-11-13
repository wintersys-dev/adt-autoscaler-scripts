#!/bin/sh
###################################################################################
# @file        DeleteRecord.sh
# @brief       Deletes DNS record(s) matching a target FQDN and IP address.
# @author      Peter Winter
# @date        13/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) into
#              sub-domain and baseline zone properties, resolves the active orchestration
#              tool (CLI or API), queries provider catalogs to locate the domain zone ID
#              and all matching DNS record IDs pointing to the specified IP address, and
#              executes delete_record.sh to purge them cleanly.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "://domain.com").
# @param       $2  [Required] The target IP address whose DNS record(s) should be removed.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - software.dat configuration file defining the active ORCHESTRATION_TOOL.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - external dependencies: cat, echo, awk, cut, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Matching DNS record(s) deleted cleanly (or none found).
# @exit        1  Failure: Missing context paths, input parameter errors, or API/CLI failures.
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
        /bin/echo "Error: Fully Qualified Domain Name and target IP parameters are required."
        /bin/echo "Usage: $0 <fqdn> <target_ip>"
        exit 1
fi

sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
target_ip="${2}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

if [ -z "${TOKEN}" ] || [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN or DNS_CHOICE)." >&2
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

if [ ! -d "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# 1. Fetch domains list and resolve domain_id
set +e
domain_json="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        /bin/echo "Failed to query cluster domain management catalog or network timeout occurred." >&2
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
        /bin/echo "Domain ID not found matching zone pattern: ${domain_url}" >&2
        exit 1
fi

# 2. Fetch all DNS records for the target domain
set +e
records_json="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_record_ids.sh" "${domain_id}")"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${records_json}" ]
then
        /bin/echo "Failed to retrieve DNS records list for domain '${domain_url}' (ID: ${domain_id})." >&2
        exit 1
fi

records_err_msg="$(/bin/echo "${records_json}" | /usr/bin/jq -r 'if type == "object" and .errors then (.errors | if type == "array" then first.reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${records_err_msg}" ]
then
        /bin/echo "Failed to retrieve DNS records. Cloud Provider Reason: ${records_err_msg}" >&2
        exit 1
fi

# 3. Filter matching record IDs by both subdomain name and target IP (supports both API .data[] and CLI .[] shapes)
matching_record_ids="$(/bin/echo "${records_json}" | /usr/bin/jq -r --arg sub "${sub_domain}" --arg ip "${target_ip}" '(if type == "object" and has("data") then .data else . end)[] | select(.name == $sub and .target == $ip) | .id // empty')"

if [ -z "${matching_record_ids}" ]
then
        /bin/echo "No DNS records found matching '${sub_domain}.${domain_url}' -> '${target_ip}' in zone ${domain_url}." >&2
        exit 0
fi

# 4. Delete each matching record ID cleanly
for record_id in ${matching_record_ids}
do
        set +e
        "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/delete_record.sh" "${domain_id}" "${record_id}"
        del_exit_code="$?"
        set -e

        if [ "${del_exit_code}" -ne 0 ]
        then
                /bin/echo "Error: Failed to delete DNS record ID ${record_id} from zone ${domain_url}." >&2
                exit 1
        fi

        /bin/echo "DNS record ID ${record_id} (${sub_domain}.${domain_url} -> ${target_ip}) successfully deleted from zone ${domain_url}."
done

exit 0
