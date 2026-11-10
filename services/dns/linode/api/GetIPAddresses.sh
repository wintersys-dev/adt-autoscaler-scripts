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
#              via the Linode API using bounded token scopes, and extracts the explicit
#              destination IP targets associated with the matched node.
#
# @param       $1  [Required] The target website Fully Qualified Domain Name or URL string.
#
# @env         HOME                Path to the stand-alone environment framework directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking active base home path.
#              - ExtractConfigValue.sh configuration variable extraction utility.
#              - external dependencies: cat, echo, awk, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive tokens (TOKEN) tightly inside execution tracks.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS records successfully located and targets printed.
# @exit        1  Failure: Missing context paths, input parameter errors, or API failures.
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
if [ -z "${1}" ]
then
        /bin/echo "Error: One argument is required."
        /bin/echo "Usage: $0 <website_url>" 
        exit 1
fi

# Parse localized networking components safely using modern subshells
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"

# Extract authorized structural access keys safely
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSSECURITYKEY')"

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to retrieve security token configuration key." >&2
        exit 1
fi

# Fetch active domain zone layouts securely with manual intercept hooks to catch runtime exceptions
set +e
api_domain_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "https://api.linode.com/v4/domains")"
domain_exit_code="$?"
set -e

if [ "${domain_exit_code}" -ne 0 ] || [ -z "${api_domain_json}" ]
then
        /bin/echo "DNS domain ID not successfully obtained due to API query failure" >&2
        unset TOKEN
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.data[] | select(.domain | contains($dom)) | .id // empty')"

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found via API matching zone track string pattern: ${domain_url}" >&2
        unset TOKEN
        exit 1
fi

# Query specific records associated with the matched domain ID
set +e
#api_records_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "https://linode.com/${domain_id}/records")"
api_records_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "https://api.linode.com/v4/domains")"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${api_records_json}" ]
then
        /bin/echo "DNS record not successfully obtained due to API query failure" >&2
        unset TOKEN
        exit 1
fi

# Isolate target host tracking properties matching the provided sub-domain structure cleanly
record_targets="$(/bin/echo "${api_records_json}" | /usr/bin/jq --arg sub "${sub_domain}" -r '.data[] | select(.name == $sub) | .target // empty')"

if [ -z "${record_targets}" ]
then
        /bin/echo "DNS record targets could not be identified for sub-domain: ${sub_domain}" >&2
        unset TOKEN
        exit 1
fi

# Print target record tracking output to stdout
/bin/echo "${record_targets}"
unset TOKEN

exit 0

	
