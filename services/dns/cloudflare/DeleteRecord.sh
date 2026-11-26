#!/bin/sh
#: Name:        DeleteRecord.sh
#: Purpose:     Deletes an active DNS record entry from a specified Cloudflare domain zone.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       DeleteRecord.sh <record_id> <website_url>
#:              DeleteRecord.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Unique Cloudflare identifier of the target DNS record
#:   $2         [Required] Target website Fully Qualified Domain Name (e.g., "://domain.com")
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/dns/cloudflare/GetZoneID.sh
#:   - ${HOME}/services/dns/cloudflare/<ORCHESTRATION_TOOL>/delete_record.sh
#:   - External binaries: cat, echo, grep, cut, awk
#:
#: Exit Codes:
#:   0          Target Cloudflare DNS record successfully deleted
#:   1          Missing /home/homedir.dat, missing arguments, missing zone ID, or API failure
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
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
        /bin/echo "Error: Record ID and website_url parameters are required." >&2
        /bin/echo "Usage: $0 <record_id> <website_url>" >&2
        exit 1
fi

record_id="${1}"
website_url="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

if [ -z "${DNS_CHOICE}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (DNSCHOICE)." >&2
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

if [ ! -d "${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"
zone_id="$("${HOME}/services/dns/cloudflare/GetZoneID.sh" "${zone_name}")"

if [ -z "${zone_id}" ]
then
        /bin/echo "Error: Failed to resolve Cloudflare Zone ID for '${zone_name}'." >&2
        exit 1
fi

set +e
"${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/delete_record.sh" "${zone_id}" "${record_id}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Failed to delete record ${record_id} domain ${website_url}" >&2
        exit 1
fi

/bin/echo "DNS record successfully deleted: ${website_url}"
exit 0

