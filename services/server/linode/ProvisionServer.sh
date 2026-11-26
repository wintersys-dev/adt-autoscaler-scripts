#!/bin/sh
#: Name:        ProvisionServer.sh
#: Purpose:     Provisions a Linode compute instance inside a managed VPC and subnet via the active orchestration tool.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       ProvisionServer.sh <region> <image> <server_size> <server_name> <user_data_path> <firewall_id> [snapshot_id]
#:              ProvisionServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Linode region slug for deployment
#:   $2         [Required] OS distribution image slug or custom image source
#:   $3         [Required] Server plan hardware size slug
#:   $4         [Required] Unique hostname / label assigned to the instance
#:   $5         [Required] Path to the prepared cloud-init user-data file
#:   $6         [Required] Cloud firewall ID applied to the primary interface (or -1)
#:   $7         [Optional] Overriding backup snapshot ID for recovery builds
#:
#: Environment:
#:   HOME                Resolved automatically from /home/homedir.dat and exported
#:   EMERGENCY_PASSWORD  Optional root emergency password passed to create_instance.sh
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/runtime/software.dat
#:   - ${HOME}/services/server/linode/<orchestration_tool>/list_vpcs.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/create_vpc.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/list_subnets.sh
#:   - ${HOME}/services/server/linode/<orchestration_tool>/create_instance.sh
#:   - External binaries: cat, echo, printf, grep, cut, awk, tr, head, jq
#:
#: Exit Codes:
#:   0          Linode compute instance provisioned cleanly
#:   1          Missing /home/homedir.dat, invalid arguments/files, VPC failure, or instance creation failure
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
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ]
then
        /bin/echo "Error: 6 arguments are required and 1 optional argument." >&2
        /bin/echo "Usage: ${0} <region> <image> <server_size> <server_name> <user_data_path> <firewall_id> [snapshot_id]" >&2
        exit 1
fi

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
user_data_path="${5}"
firewall_id="${6}"
snapshot_id="${7}"

if [ ! -r "${user_data_path}" ]
then
        /bin/echo "Error: Cloud-init user-data file missing or unreadable at ${user_data_path}" >&2
        exit 1
fi

if [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
VPC_IP_RANGE="$("${extract_script}" 'VPCIPRANGE')"
VPC_NAME="$("${extract_script}" 'VPCNAME')"
set -e

if [ -z "${VPC_IP_RANGE}" ] || [ -z "${VPC_NAME}" ]
then
        /bin/echo "Error: Required VPC configuration values (VPCIPRANGE or VPCNAME) are missing." >&2
        exit 1
fi

software_file="${HOME}/runtime/software.dat"
if [ ! -r "${software_file}" ]
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

if [ ! -x /usr/bin/jq ]
then
        /bin/echo "Error: /usr/bin/jq not found or not executable." >&2
        exit 1
fi

driver_dir="${HOME}/services/server/linode/${orchestration_tool}"
for req_script in list_vpcs.sh create_vpc.sh list_subnets.sh create_instance.sh
do
        if [ ! -x "${driver_dir}/${req_script}" ]
        then
                /bin/echo "Error: Linode driver script missing or not executable at ${driver_dir}/${req_script}" >&2
                exit 1
        fi
done

set +e
response_vpc="$("${driver_dir}/list_vpcs.sh" "${region}")"
vpc_status="$?"
set -e

if [ "${vpc_status}" -eq 0 ] && [ -n "${response_vpc}" ]
then
        vpc_id="$(printf '%s\n' "${response_vpc}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select((.label // "") == $lbl) | .id' | /usr/bin/head -n 1)"
else
        /bin/echo "Error: Failed to retrieve Linode VPC list for region '${region}'." >&2
        exit 1
fi

if [ -z "${vpc_id}" ] || [ "${vpc_id}" = "null" ]
then
        /bin/echo "VPC network '${VPC_NAME}' not found. Initiating dynamic deployment..." >&2
        if [ "${orchestration_tool}" = "api" ]
        then
                vpc_payload="$(/usr/bin/jq -n --arg lbl "${VPC_NAME}" --arg reg "${region}" --arg ip "${VPC_IP_RANGE}" '{label: $lbl, region: $reg, subnets: [{label: "adt-subnet", ipv4: $ip}]}')"
        elif [ "${orchestration_tool}" = "cli" ]
        then
                vpc_payload="--label \"${VPC_NAME}\" --region \"${region}\" --subnets.label \"adt-subnet\" --subnets.ipv4 \"${VPC_IP_RANGE}\""
        else
                /bin/echo "Error: Unsupported ORCHESTRATION_TOOL '${orchestration_tool}'." >&2
                exit 1
        fi

        set +e
        response_create_vpc="$("${driver_dir}/create_vpc.sh" "${vpc_payload}")"
        create_vpc_status="$?"
        set -e

        if [ "${create_vpc_status}" -eq 0 ] && [ -n "${response_create_vpc}" ]
        then
                vpc_id="$(printf '%s\n' "${response_create_vpc}" | /usr/bin/jq -r '.id // empty' | /usr/bin/head -n 1)"

                if [ -z "${vpc_id}" ] || [ "${vpc_id}" = "null" ]
                then
                        set +e
                        response_vpc_refresh="$("${driver_dir}/list_vpcs.sh" "${region}")"
                        refresh_status="$?"
                        set -e

                        if [ "${refresh_status}" -eq 0 ] && [ -n "${response_vpc_refresh}" ]
                        then
                                vpc_id="$(printf '%s\n' "${response_vpc_refresh}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select((.label // "") == $lbl) | .id' | /usr/bin/head -n 1)"
                        else
                                /bin/echo "Error: Network request failed during VPC landscape refresh." >&2
                                exit 1
                        fi
                fi
        else
                /bin/echo "Error: Dynamic VPC creation failed for '${VPC_NAME}'." >&2
                exit 1
        fi
fi

if [ -z "${vpc_id}" ] || [ "${vpc_id}" = "null" ]
then
        /bin/echo "Error: Unable to resolve VPC ID for '${VPC_NAME}'." >&2
        exit 1
fi

set +e
response_subnet="$("${driver_dir}/list_subnets.sh" "${vpc_id}")"
subnet_status="$?"
set -e

if [ "${subnet_status}" -eq 0 ] && [ -n "${response_subnet}" ]
then
        subnet_id="$(printf '%s\n' "${response_subnet}" | /usr/bin/jq -r --arg lbl "adt-subnet" '.[] | select((.label // "") == $lbl) | .id' | /usr/bin/head -n 1)"
else
        /bin/echo "Error: Failed to list subnets for VPC ID '${vpc_id}'." >&2
        exit 1
fi

if [ -z "${subnet_id}" ] || [ "${subnet_id}" = "null" ]
then
        /bin/echo "Error: Failed to obtain VPC subnet ID for 'adt-subnet' in VPC '${vpc_id}'." >&2
        exit 1
fi

password_token="${EMERGENCY_PASSWORD:-none}"
parameter_payload="${password_token} ${region} ${image} ${server_size} ${server_name} ${firewall_id} ${subnet_id} ${user_data_path}"

set +e
response_instance="$(printf '%s\n' "${parameter_payload}" | "${driver_dir}/create_instance.sh")"
create_status="$?"
set -e

if [ "${create_status}" -eq 0 ] && [ -n "${response_instance}" ]
then
        /bin/echo "Success: Compute instance '${server_name}' successfully provisioned."
        exit 0
else
        /bin/echo "Error: Failed to provision compute instance '${server_name}'." >&2
        exit 1
fi

