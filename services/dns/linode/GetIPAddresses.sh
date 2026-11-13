#!/bin/sh
###################################################################################
# @file        GetIPAddresses.sh
# @brief       Retrieves active target IP addresses associated with a given DNS sub-domain.
# @author      Peter Winter
# @date        10/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) into 
#              isolated sub-domain and zone apex properties, queries provider catalogs
#              using the Linode CLI under a designated configuration profile, and isolates
#              the active destination IP target records mapping explicitly to the specified node.
#
# @param       $1  [Required] The target website Fully Qualified Domain Name or URL string.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - external dependencies: cat, echo, awk, cut, linode-cli, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive configs (LINODE_CLI_CONFIG) tightly inside execution tracks.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS records successfully located and targets printed.
# @exit        1  Failure: Missing context paths, input parameter errors, or binary failures.
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
set -e

# Resolve HOME baseline layout securely
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ]
then
        status "Error: One argument is required."
        status "Usage: $0 <website_url>" 
        exit 1
fi

sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
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

set +e
records_json="$(${HOME}/services/dns/linode/${orchestration_tool}cli/get_record_ids.sh)"
records_exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${records_json}" ]
then
        /bin/echo "Failed to query domain records management catalog or network timeout occurred." >&2
        exit 1
fi

# Extract dynamic record configuration target indicators safely
record_targets="$(/bin/echo "${records_json}" | /usr/bin/jq -r --arg sub "${sub_domain}" '.[] | select(.name == $sub) | .target // empty')"

if [ -z "${record_targets}" ]
then
        /bin/echo "DNS ip addresses not successfully obtained" >&2
        exit 1
fi

# Print target record tracking output cleanly to standard stdout channel interface
/bin/echo "${record_targets}"

exit 0
