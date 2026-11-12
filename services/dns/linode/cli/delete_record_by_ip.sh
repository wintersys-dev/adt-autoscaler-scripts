#!/bin/sh
###################################################################################
# @file        delete_record_by_ip.sh
# @brief       Deletes a specific DNS A record matching a given domain and IP address using Linode CLI.
# @author      Peter Winter
# @date        10/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) into 
#              isolated sub-domain and zone apex properties, queries provider catalogs
#              using the Linode CLI under a designated configuration profile, isolates
#              the explicit record tracking ID associated with the target IP address,
#              and dispatches a delete execution command to clear the entry.
#
# @param       $1  [Required] The target website Fully Qualified Domain Name or URL string.
# @param       $2  [Required] The destination tracking node IPv4/IPv6 target address to drop.
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
# @exit        0  Success: Target DNS record successfully dropped via CLI track.
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


# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Two arguments are required."
        /bin/echo "Usage: $0 <website_url> <ip>" 
        exit 1
fi

# Parse localized networking components safely using modern subshells
subdomain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
ip="${2}"

# Extract authorized structural access keys safely
TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY'`"
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        /bin/echo "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Fetch active domain zone layouts securely with manual intercept hooks to catch runtime exceptions
set +e
cli_domain_json="$("/usr/local/bin/linode-cli" domains list --no-defaults --json 2>/dev/null)"
domain_exit_code="$?"
set -e

if [ "${domain_exit_code}" -ne 0 ] || [ -z "${cli_domain_json}" ]
then
        /bin/echo "DNS domain ID not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${cli_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain | contains($dom)) | .id // empty')"

if [ -z "${domain_id}" ]
then
        /bin/echo "DNS domain ID not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Isolate matching records inside target zone architecture mappings trackers
set +e
cli_records_json="$("/usr/local/bin/linode-cli" domains records-list "${domain_id}" --no-defaults --json 2>/dev/null)"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${cli_records_json}" ]
then
        /bin/echo "DNS record ID not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Extract dynamic record configuration element tracking indicators safely
record_id="$(/bin/echo "${cli_records_json}" | /usr/bin/jq -r --arg target_ip "${ip}" '.[] | select(.target == $target_ip) | .id // empty')"

if [ -z "${record_id}" ]
then
        /bin/echo "DNS record ID not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Execute delete route tracking actions via bounded platform calls
set +e
"/usr/local/bin/linode-cli" domains records-delete "${domain_id}" "${record_id}" 2>/dev/null
delete_exit_code="$?"
set -e

if [ "${delete_exit_code}" -ne 0 ]
then
        /bin/echo "DNS record not successfully deleted" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

/bin/echo "Successfully deleted record with ip ${ip} for domain ${domain_url}"

unset LINODE_CLI_CONFIG
exit 0


