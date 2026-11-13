#!/bin/sh
###################################################################################
# @file        get_domain_id.sh
# @brief       Extracts the Linode domain identifier matching a target domain URL from JSON.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script validates the raw domain listing JSON payload and target domain
#              URL arguments, passes the domain string safely via jq parameter binding,
#              and streams the matching numerical domain identifier to standard output.
#
# @param       $1  [Required] The raw JSON payload returned by the Linode domains endpoint.
# @param       $2  [Required] The target domain URL or substring to match against records.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedirdat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, jq
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses jq --arg binding to prevent filter injection from untrusted domain strings.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Matching domain identifier extracted cleanly.
# @exit        1  Failure: Missing arguments, layout faults, or malformed JSON input.
# @exit        2  Not Found: No domain record matched the specified domain URL.
##################################################################################
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
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Domain JSON payload and target domain URL arguments are required." >&2
        /bin/echo "Usage: $0 <domain_json> <domain_url>" >&2
        exit 1
fi

domain_json="${1}"
domain_url="${2}"

set +e
DOMAIN_ID=$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)
JQ_EXIT_CODE=$?
set -e

if [ "${JQ_EXIT_CODE}" -ne 0 ]
then
        /bin/echo "Error: Failed to parse domain JSON payload with jq (exit code ${JQ_EXIT_CODE})." >&2
        exit 1
fi

if [ -z "${DOMAIN_ID}" ]
then
        /bin/echo "Error: No matching domain ID found for domain '${domain_url}'." >&2
        exit 2
fi

/bin/echo "${DOMAIN_ID}"
exit 0
