#!/bin/sh
###################################################################################
# @file        ProvisionServer.sh
# @brief       Provisions a Linode compute instance securely within a managed VPC.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 API to provision a virtual
#              machine. It validates the existence of the targeted Virtual Private
#              Cloud (VPC), dynamically creates the VPC and its core subnet if 
#              missing, resolves the relevant internal subnet IDs, and executes 
#              the final infrastructure deployment transaction securely using 
#              piped authorization streams.
#
# @param       $1  [Required] The target Linode region slug for deployment location.
# @param       $2  [Required] The OS distribution image slug or custom image source.
# @param       $3  [Required] The server plan hardware size and performance profile tier.
# @param       $4  [Required] The human-readable label/hostname for the instance.
# @param       $5  [Required] Path to the prepared cloud-init user data file.
# @param       $6  [Required] The security firewall ID applied to the primary interface.
# @param       $7  [Optional] Overriding backup snapshot ID matching a recovery build.
#
# @env         HOME                Path to the toolkit core framework layout directory.
# @env         VPC_IP_RANGE        The network block CIDR configured for VPC initialization.
# @env         VPC_NAME            The matching environment tag pattern for infrastructure filtering.
# @env         REGION              The region that the servers are running in.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: curl, jq, base64, sed, tail, cat, mkdir, hostname, expr
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
#
# @exit        0  Success: The server instance was successfully instantiated and registered.
# @exit        1  Failure: Argument mismatch, invalid VPC configurations, or an unexpected
#                 HTTP error encountered during processing via the cloud host provider API.
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
####################################################################################
set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ] 
then
        /bin/echo "Error: 6 arguments are required and 1 optional argument" >&2
        /bin/echo "Usage: $0 <region> <image> <server_size> <server_name> <user_data> <firewall_id> [snapshot_id]" >&2
        exit 1
fi

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
user_data_path="${5}"
firewall_id="${6}"
snapshot_id="${7}"


if [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

set +e
REGION="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REGION')"
VPC_IP_RANGE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE')"
VPC_NAME="$(${HOME}/utilities/config/ExtractConfigValue.sh 'VPCNAME')"
set -e

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

# Evaluate the active platform VPC landscape topology via safe headers
# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response_vpc="$(${HOME}/services/server/linode/${orchestration_tool}/list_vpcs.sh "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response_vpc}" ]
then
        vpc_id="$(/bin/echo "${response_vpc}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select(.label == $lbl).id')"
else
        /bin/echo "Network request failed. Check your API token or URL." >&2
        exit 1
fi

if [ -z "${vpc_id}" ] 
then
        /bin/echo "VPC network not found. Initiating dynamic deployment schema..." >&2
        if [ "${orchestration_tool}" = "api" ]
        then
                vpc_payload="$(/usr/bin/jq -n --arg lbl "${VPC_NAME}" --arg reg "${REGION}" --arg ip "${VPC_IP_RANGE}" '{label: $lbl, region: $reg, subnets: [{label: "adt-subnet", ipv4: $ip}]}')"
        elif [ "${orchestration_tool}" = "cli" ]
        then
                vpc_payload='--label "'${VPC_NAME}'" --region "'${REGION}'" --subnets.label "'adt-subnet'" --subnets.ipv4 "'${VPC_IP_RANGE}'"'
        fi
        # Temporary disable set -e to evaluate curl transaction pipeline failures manually
        set +e
        response_create_vpc="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/create_vpc.sh "${vpc_payload}")"
        curl_status="$?"
        set -e

        if [ "${curl_status}" -eq 0 ] && [ -n "${response_create_vpc}" ]
        then
                # Extract the newly created ID directly from the creation response payload
                vpc_id="$(/bin/echo "${response_create_vpc}" | /usr/bin/jq -r '.id')"

                # Double-check fallback: If ID wasn't in response, refresh manually
                if [ -z "${vpc_id}" ] || [ "${vpc_id}" = "null" ]
                then
                        set +e
                        response_vpc_refresh="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_vpcs.sh "${REGION}")"
                        curl_status="$?"
                        set -e

                        if [ "${curl_status}" -eq 0 ] && [ -n "${response_vpc_refresh}" ]
                        then
                                vpc_id="$(/bin/echo "${response_vpc_refresh}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select(.label == $lbl).id')"
                        else
                                /bin/echo "Network request failed during VPC landscape refresh." >&2
                                exit 1
                        fi
                fi
        else
                /bin/echo "Network request failed. Dynamic VPC creation failed." >&2
                exit 1
        fi
fi

# Fetch subnets for the established VPC
# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response_subnet="$(${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_subnets.sh "${vpc_id}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response_subnet}" ]
then
        subnet_id="$(/bin/echo "${response_subnet}" | /usr/bin/jq -r --arg lbl "adt-subnet" '.[] | select(.label == $lbl).id')"
else
        /bin/echo "Network request failed. Check your API token or URL." >&2
        exit 1
fi

if [ -z "${subnet_id}" ] 
then
        /bin/echo "Error: Failed to obtain VPC subnet id mapping rules." >&2
        exit 1
fi

parameter_payload="${EMERGENCY_PASSWORD} ${region} ${image} ${server_size} ${server_name} ${firewall_id} ${subnet_id} ${user_data_path}"

set +e

response_instance=$(/bin/echo "${parameter_payload}" | ${BUILD_HOME}/services/server/linode/${orchestration_tool}/create_instance.sh)

curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response_instance}" ]
then
        /bin/echo "Success: Compute instance '${server_name}' successfully provisioned." >&2
        exit 0
else
        /bin/echo "Network request failed. Check your API token or URL." >&2
        exit 1
fi
