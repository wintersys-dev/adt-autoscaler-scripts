#!/bin/sh
#: Name:        AdjustDBaaSFirewall.sh
#: Purpose:     Tightens the DBaaS managed database firewall allow list to active fleet and multi-region IPs.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       AdjustDBaaSFirewall.sh [ip_to_delete]
#:              AdjustDBaaSFirewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] IPv4 address queued for removal from the allow list during node teardown
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/ExtractConfigValues.sh
#:   - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#:   - ${HOME}/services/datastore/operations/ListFromDatastore.sh
#:   - ${HOME}/services/server/GetServerPublicIPAddresses.sh
#:   - ${HOME}/services/dbaas/<cloudhost>/<tool>/<engine>/list_database.sh
#:   - ${HOME}/services/dbaas/<cloudhost>/<tool>/<engine>/update_database_firewall.sh
#:   - External binaries: cat, echo, printf, mkdir, touch, grep, sed, awk, tr, sort, jq
#:
#: Exit Codes:
#:   0          DBaaS firewall allow list evaluated and updated cleanly (or no changes required)
#:   1          Missing /home/homedir.dat, missing context variables, unresolved DB ID, or driver failure
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

# Resolve the server toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
        export HOME
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

ip_to_delete="${1}"

config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"
config_multi_extractor="${HOME}/utilities/config/ExtractConfigValues.sh"
style_extractor="${HOME}/utilities/config/ExtractBuildStyleValues.sh"

set +e
TOKEN="$("${config_extractor}" 'TOKEN')"
BUILD_IDENTIFIER="$("${config_extractor}" 'BUILDIDENTIFIER')"
REGION="$("${config_extractor}" 'REGION')"
CLOUDHOST="$("${config_extractor}" 'CLOUDHOST')"
MULTI_REGION="$("${config_extractor}" 'MULTIREGION')"
PRIMARY_REGION="$("${config_extractor}" 'PRIMARYREGION')"
VPC_IP_RANGE="$("${config_extractor}" 'VPCIPRANGE')"
DATABASE_DBAAS_INSTALLATION_TYPE="$("${config_extractor}" 'DATABASEDBaaSINSTALLATIONTYPE')"
[ -z "${DATABASE_DBAAS_INSTALLATION_TYPE}" ] && DATABASE_DBAAS_INSTALLATION_TYPE="$("${config_extractor}" 'DATABASE_DBAAS_INSTALLATION_TYPE')"
set -e

if [ -z "${TOKEN}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${REGION}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${VPC_IP_RANGE}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN, BUILD_IDENTIFIER, REGION, CLOUDHOST, or VPC_IP_RANGE)." >&2
        exit 1
fi

database_engine="mysql"
case "${DATABASE_DBAAS_INSTALLATION_TYPE}" in
        *Postgres*|*postgres*)
                database_engine="postgres"
                ;;
esac

set +e
orchestration_tool="$("${style_extractor}" "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}')"
set -e

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: Failed to determine orchestration tool." >&2
        exit 1
fi

allowed_ips_dir="${HOME}/runtime/dbaas_allowed_ips"
ip_list_file="${allowed_ips_dir}/ip_list.dat"

if [ ! -d "${allowed_ips_dir}" ]
then
        /bin/mkdir -p "${allowed_ips_dir}"
fi

multi_region_ips=""

if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" != "1" ]
then
        set +e
        multi_region_ips="$("${HOME}/services/datastore/operations/ListFromDatastore.sh" "multi-region" "dbaas_ips/*" 2>/dev/null | /usr/bin/awk -F'/' '{print $NF}')"
        set -e

        /usr/bin/touch "${ip_list_file}"

        modified="no"
        for ip in ${multi_region_ips}
        do
                [ -z "${ip}" ] && continue
                if ! /bin/grep -qxF "${ip}" "${ip_list_file}"
                then
                        /bin/echo "${ip}" >> "${ip_list_file}"
                        modified="yes"
                fi
        done

        while IFS= read -r existing_ip
        do
                [ -z "${existing_ip}" ] && continue
                if ! printf '%s\n' ${multi_region_ips} | /bin/grep -qxF "${existing_ip}"
                then
                        escaped_ip="$(printf '%s' "${existing_ip}" | /bin/sed -e 's/[\\.*^$[\]/]/\\&/g')"
                        /bin/sed -i "/^${escaped_ip}$/d" "${ip_list_file}"
                        modified="yes"
                fi
        done < "${ip_list_file}"

        if [ "${modified}" = "no" ] && [ -z "${ip_to_delete}" ]
        then
                /bin/echo "Success: No multi-region IP changes detected for DBaaS firewall."
                exit 0
        fi
fi

set +e
label="$("${config_multi_extractor}" "DATABASEDBaaSINSTALLATIONTYPE" "stripped" | /usr/bin/awk '{print $7}')"
set -e

if [ -z "${label}" ]
then
        /bin/echo "Error: Failed to extract target DBaaS label." >&2
        exit 1
fi

list_script="${HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_engine}/list_database.sh"
if [ ! -x "${list_script}" ]
then
        /bin/echo "Error: Database listing script missing or not executable at ${list_script}." >&2
        exit 1
fi

trap 'unset LINODE_CLI_TOKEN' EXIT INT TERM
export LINODE_CLI_TOKEN="${TOKEN}"

set +e
database_id="$("${list_script}" | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label | contains($lbl)) | .id' | /usr/bin/head -n 1)"
set -e

unset LINODE_CLI_TOKEN
trap - EXIT INT TERM

if [ -z "${database_id}" ]
then
        /bin/echo "Error: Unable to locate DBaaS instance matching label '${label}'." >&2
        exit 1
fi

set +e
webserver_ips="$("${HOME}/services/server/GetServerPublicIPAddresses.sh" "ws-${REGION}-${BUILD_IDENTIFIER}")"
database_ips="$("${HOME}/services/server/GetServerPublicIPAddresses.sh" "db-${REGION}-${BUILD_IDENTIFIER}")"
set -e

# Deduplicate fleet + multi-region IPs and filter out any ip_to_delete queued during node teardown
ip_addresses="$(
        for ip in ${webserver_ips} ${database_ips} ${multi_region_ips}
        do
                [ -z "${ip}" ] && continue
                if [ -n "${ip_to_delete}" ] && { [ "${ip}" = "${ip_to_delete}" ] || [ "${ip}" = "${ip_to_delete}/32" ]; }
                then
                        continue
                fi
                printf '%s\n' "${ip}"
        done | /usr/bin/sort -u | /usr/bin/tr '\n' ' ' | /bin/sed 's/[[:space:]]*$//'
)"

adjust_script="${HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_engine}/update_database_firewall.sh"

if [ ! -x "${adjust_script}" ]
then
        /bin/echo "Error: Adjustment script missing or not executable at ${adjust_script}." >&2
        exit 1
fi

set +e
"${adjust_script}" "${database_id}" "${ip_addresses}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: AdjustDBaaSFirewall.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

printf '%s\n' ${ip_addresses} > "${ip_list_file}"

/bin/echo "Success: DBaaS firewall allow list updated for database ${database_id}."
exit 0

