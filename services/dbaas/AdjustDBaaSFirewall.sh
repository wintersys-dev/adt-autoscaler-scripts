#!/bin/sh
###################################################################################
# @file        AdjustDBaaSFirewall.sh
# @brief       Tightens the Linode DBaaS firewall allow list to trusted fleet IPs.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script resolves deployment context variables, queries active
#              webserver, database, and multi-region IP addresses, identifies the
#              target Linode MySQL or PostgreSQL managed database ID, constructs a
#              restricted allow-list payload, and delegates the firewall adjustment
#              to the active orchestration provider script.
#
# @param       $1  [Optional] IP address queued for deletion (if invoked during teardown).
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/utilities/config/ExtractConfigValue.sh
#              - ${HOME}/utilities/config/ExtractConfigValues.sh
#              - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#              - ${HOME}/services/datastore/operations/ListFromDatastore.sh
#              - ${HOME}/services/server/GetServerPublicIPAddresses.sh
#              - ${HOME}/services/dbaas/<cloudhost>/<tool>/<engine>/AdjustDBaaSFirewall.sh
#              - external dependencies: cat, echo, mkdir, touch, grep, sed, awk, tr, sort, jq, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate hijack vectors.
#              - Replaces legacy backticks with modern POSIX command substitutions.
#              - Uses jq --arg parameterization to safely match database labels without injection.
#              - Quotes variable interpolations thoroughly and unsets tokens post-execution.
#
# @exit        0  Success: DBaaS firewall allow list evaluated and updated cleanly.
# @exit        *  Failure: Missing configuration files, missing required context values,
#                 unresolved database ID, or cascading exit failures from toolkit helpers.
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

ip_to_delete="${1}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
BUILD_IDENTIFIER="$(${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER')"
REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REGION')"
CLOUDHOST="$(${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST')"
MULTI_REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'MULTIREGION')"
PRIMARY_REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'PRIMARYREGION')"
WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
VPC_IP_RANGE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE')"
DATABASE_DBAAS_INSTALLATION_TYPE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DATABASE_DBAAS_INSTALLATION_TYPE')"
set -e

if [ -z "${TOKEN}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${REGION}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${VPC_IP_RANGE}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN, BUILD_IDENTIFIER, REGION, CLOUDHOST, or VPC_IP_RANGE)." >&2
        exit 1
fi

database_engine="mysql"
if /bin/echo "${DATABASE_DBAAS_INSTALLATION_TYPE}" | /bin/grep -q 'Postgres'
then
        database_engine="postgres"
fi

set +e
orchestration_tool="$(${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}')"
set -e

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: Failed to determine orchestration tool." >&2
        exit 1
fi

multi_region_ips=""

if [ ! -d "${HOME}/runtime/dbaas_allowed_ips" ]
then
        /bin/mkdir -p "${HOME}/runtime/dbaas_allowed_ips"
fi

if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" != "1" ]
then
        multi_region_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-multi-region"
        
        set +e
        multi_region_ips="$(${HOME}/services/datastore/operations/ListFromDatastore.sh "multi-region" "dbaas_ips/*" | /usr/bin/awk -F'/' '{print $NF}')"
        set -e

        /bin/touch "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat"

        modified="no"
        for ip in ${multi_region_ips}
        do
                if ! /bin/grep -qxF "${ip}" "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat"
                then
                        /bin/echo "${ip}" >> "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat"
                        modified="yes"
                fi
        done

        for existing_ip in $(/bin/cat "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat")
        do
                if ! /bin/echo "${multi_region_ips}" | /bin/grep -qwF "${existing_ip}"
                then
                        /bin/sed -i "#^${existing_ip}$#d" "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat"
                        modified="yes"
                fi
        done

        if [ "${modified}" = "no" ]
        then
                /bin/echo "Success: No multi-region IP changes detected for DBaaS firewall."
                exit 0
        fi
fi

set +e
dbaas="$(${HOME}/utilities/config/ExtractConfigValues.sh "DATABASEDBaaSINSTALLATIONTYPE" "stripped")"
label="$(${HOME}/utilities/config/ExtractConfigValues.sh "DATABASEDBaaSINSTALLATIONTYPE" "stripped" | /usr/bin/awk '{print $7}')"
set -e

if [ -z "${label}" ]
then
        /bin/echo "Error: Failed to extract target DBaaS label." >&2
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
database_id="$(${HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_engine}/ListDatabases.sh | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label | contains($lbl)) | .id' | /usr/bin/head -n 1)"
set -e

# Unset token instantly to maintain high security-isolation states
unset LINODE_CLI_TOKEN

if [ -z "${database_id}" ]
then
        /bin/echo "Error: Unable to locate Linode DBaaS instance matching label ${label}." >&2
        exit 1
fi

set +e
webserver_ips="$(${HOME}/services/server/GetServerPublicIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}")"
database_ips="$(${HOME}/services/server/GetServerPublicIPAddresses.sh "db-${REGION}-${BUILD_IDENTIFIER}")"
set -e

ipaddresses="${webserver_ips} ${database_ips}"

if [ -n "${multi_region_ips}" ]
then
        for ip in ${multi_region_ips}
        do
                ipaddresses="${ipaddresses} ${ip}"
        done
fi

ipaddresses="$(/bin/echo "${ipaddresses}" | /usr/bin/tr ' ' '\n' | /bin/grep -v '^$' | /usr/bin/sort -u)"

allow_list=""
for ipaddress in ${ipaddresses}
do
        if [ -n "${ip_to_delete}" ] && [ "${ipaddress}" = "${ip_to_delete}" ]
        then
                continue
        fi
        allow_list="${allow_list} --allow_list ${ipaddress}/32"
done

allow_list="${allow_list} --allow_list ${VPC_IP_RANGE}"

adjust_script="${HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_engine}/update_database_firewall.sh"

if [ ! -x "${adjust_script}" ]
then
        /bin/echo "Error: Adjustment script missing or not executable at ${adjust_script}." >&2
        exit 1
fi

set +e
"${adjust_script}" "${database_id}" "${allow_list}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: AdjustDBaaSFirewall.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

/bin/echo "${ipaddresses}" > "${HOME}/runtime/dbaas_allowed_ips/ip_list.dat"

/bin/echo "Success: DBaaS firewall allow list updated for database ${database_id}."
exit 0
