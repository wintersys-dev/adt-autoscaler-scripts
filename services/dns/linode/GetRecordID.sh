#!/bin/sh
#: Name:        GetRecordID.sh
#: Purpose:     Resolves the unique Linode DNS record identifier matching an FQDN and IP address.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       GetRecordID.sh <fqdn> <target_ip>
#:              GetRecordID.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Fully Qualified Domain Name (e.g., "://domain.com")
#:   $2         [Required] Target IPv4/IPv6 address to match against DNS records
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/dns/<DNSCHOICE>/<ORCHESTRATION_TOOL>/get_domains.sh
#:   - ${HOME}/services/dns/<DNSCHOICE>/<ORCHESTRATION_TOOL>/get_record_ids.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Matching DNS record ID successfully resolved and printed to stdout
#:   1          Missing /home/homedir.dat, missing arguments, missing domain/record ID, or API/CLI failure
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
# along with The Wintersys Agile Deployment Toolkit.  If not, see <http://gnu.org>.
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
target_ip="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (DNS_CHOICE)." >&2
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

domain_id=$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain == $dom) | .id // empty' 2>/dev/null)

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        exit 1
fi

set +e
records_json="$("${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_record_ids.sh" "${domain_id}")"
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
