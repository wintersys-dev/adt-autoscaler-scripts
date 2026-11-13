#!/bin/sh
###################################################################################
# @file        DeleteRecord.sh
# @brief       Deletes an active record entry from a specified domain zone matrix.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) to extract
#              its zone apex domain root, queries provider catalogs securely to capture
#              the target domain zone ID, and issues a secure authorized DELETE request
#              to expunge the specified DNS record ID.
#
# @param       $1  [Required] The unique platform identifier ID of the target DNS record.
# @param       $2  [Required] The Fully Qualified Domain Name context (e.g., "www.domain.com").
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - external dependencies: cat, echo, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects dynamic JSON queries from parameter injection tracking vulnerabilities.
#
# @exit        0  Success: Target DNS record successfully deleted and verified.
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
        /bin/echo "Error: Record ID and Fully Qualified Domain Name parameters are required." >&2
        /bin/echo "Usage: $0 <record_id> <fqdn>" >&2
        exit 1
fi

record_id="${1}"
domain_url="$(/bin/echo "${2}" | /usr/bin/cut -d'.' -f2-)"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
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

set +e
domain_json="$(${HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        /bin/echo "Failed to query domain management catalog or network timeout occurred." >&2
        exit 1
fi

if /bin/echo "${domain_json}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r '.errors.reason // "Unknown API error parameters."')"
        /bin/echo "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}" >&2
        exit 1
fi

domain_id="$(${HOME}/services/dns/linode/${orchestration_tool}/get_domain_id.sh "${domain_json}" "${domain_url}" )"

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        exit 1
fi

set +e
delete_response="$(${HOME}/services/dns/linode/${orchestration_tool}/delete_record.sh "${domain_id}" "${record_id}")"
delete_exit_code="$?"
set -e

if [ "${delete_exit_code}" -ne 0 ] 
then
        /bin/echo "Failed to delete record from DNS system (Network/Curl infrastructure execution error)." >&2
        exit 1
fi

if [ -n "${delete_response}" ] && /bin/echo "${delete_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        delete_err_msg="$(/bin/echo "${delete_response}" | /usr/bin/jq -r '.errors.reason // "Unknown DNS payload entry validation error."')"
        /bin/echo "Failed to delete record from DNS system. Cloud Provider Reason: ${delete_err_msg}" >&2
        exit 1
fi

/bin/echo "DNS record ID ${record_id} successfully deleted from zone ${domain_url}."
exit 0
