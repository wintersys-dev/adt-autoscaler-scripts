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
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
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

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Input validation
if [ -z "${1}" ]
then
        status "Error: One argument is required."
        status "Usage: $0 <website_url>" 
        exit 1
fi

# Parse localized networking components safely using modern subshells
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"

# Identify appropriate CLI profile file target layout locations path configurations
linode_config_file="/root/.config/dns-linode-cli"
        
if [ -f /root/snap/linode-cli/current/.config/dns-linode-cli ]
then
        linode_config_file="/root/snap/linode-cli/current/.config/dns-linode-cli"
fi
                        
# Export configuration properties cleanly inside localized framework bounds environment tracks
export LINODE_CLI_CONFIG="${linode_config_file}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
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
cli_records_json="$("/usr/local/bin/linode-cli" domains records-list "${domain_id}" --json 2>/dev/null)"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${cli_records_json}" ]
then
        /bin/echo "DNS ip addresses not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Extract dynamic record configuration target indicators safely
record_targets="$(/bin/echo "${cli_records_json}" | /usr/bin/jq -r --arg sub "${sub_domain}" '.[] | select(.name == $sub) | .target // empty')"

if [ -z "${record_targets}" ]
then
        /bin/echo "DNS ip addresses not successfully obtained" >&2
        unset LINODE_CLI_CONFIG
        exit 1
fi

# Print target record tracking output cleanly to standard stdout channel interface
/bin/echo "${record_targets}"
unset LINODE_CLI_CONFIG

exit 0


