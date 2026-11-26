#!/bin/sh
#: Name:        ProvisionServer.sh
#: Purpose:     Prepares cloud-init user-data, image/snapshot ID, and native firewall ID, then triggers instance provisioning.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ProvisionServer.sh <server_size> <server_name>
#:              ProvisionServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Cloud provider hardware size plan / tier slug
#:   $2         [Required] Unique hostname / label assigned to the provisioned server
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/server/GetOperatingSystemVersion.sh
#:   - ${HOME}/autoscaler/InitialiseCloudInit.sh
#:   - ${HOME}/services/security/firewall/ConfigureNativeFirewall.sh
#:   - ${HOME}/services/server/<cloudhost>/ProvisionServer.sh
#:   - External binaries: cat, echo, grep, cut, sed, awk, cp, chmod
#:
#: Exit Codes:
#:   0          Cloud instance provisioned cleanly by provider driver
#:   1          Missing /home/homedir.dat, invalid arguments, missing config/cloud-init, or provider failure
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: 2 server arguments are required." >&2
        /bin/echo "Usage: ${0} <server_size> <server_name>" >&2
        exit 1
fi

server_size="${1}"
server_name="${2}"

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
os_version_script="${HOME}/services/server/GetOperatingSystemVersion.sh"
cloud_init_script="${HOME}/autoscaler/InitialiseCloudInit.sh"

if [ ! -x "${extract_script}" ] || [ ! -x "${os_version_script}" ] || [ ! -x "${cloud_init_script}" ]
then
        /bin/echo "Error: Required helper scripts missing or not executable under ${HOME}." >&2
        exit 1
fi

set +e
CLOUDHOST="$("${extract_script}" 'CLOUDHOST')"
REGION="$("${extract_script}" 'REGION')"
ACTIVE_FIREWALLS="$("${extract_script}" 'ACTIVEFIREWALLS')"
BUILD_FROM_SNAPSHOT="$("${extract_script}" 'BUILDFROMSNAPSHOT')"
OS_CHOICE="$("${os_version_script}" 2>/dev/null | /bin/sed "s/'//g")"
set -e

if [ -z "${CLOUDHOST}" ] || [ -z "${REGION}" ]
then
        /bin/echo "Error: Required configuration values (CLOUDHOST or REGION) are missing." >&2
        exit 1
fi

"${cloud_init_script}"

yaml_template="${HOME}/runtime/cloud-init/webserver.yaml"
if [ ! -r "${yaml_template}" ]
then
        /bin/echo "Error: Cloud config file not found at ${yaml_template}" >&2
        exit 1
fi

user_data_path="${HOME}/runtime/cloud-init/webserver-${server_name}.yaml"
(
        umask 077
        /bin/cp "${yaml_template}" "${user_data_path}"
        /bin/chmod 600 "${user_data_path}"
)
/bin/sed -i "s|XXXXWEBSERVER_HOSTNAMEXXXX|${server_name}|g" "${user_data_path}"

snapshot_id=""
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ]
then
        set +e
        snapshot_id="$("${extract_script}" 'SNAPSHOTID')"
        set -e
fi

image="${OS_CHOICE}"
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

if [ -z "${image}" ]
then
        /bin/echo "Error: Unable to resolve OS image or snapshot ID for provisioning." >&2
        exit 1
fi

firewall_id=""
if [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ]
then
        native_fw_script="${HOME}/services/security/firewall/ConfigureNativeFirewall.sh"
        if [ -x "${native_fw_script}" ]
        then
                set +e
                firewall_id="$("${native_fw_script}" "adt-webserver" 2>/dev/null | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print $NF}')"
                set -e
        fi
fi

if [ -z "${firewall_id}" ]
then
        firewall_id="-1"
fi

script_path="${HOME}/services/server/${CLOUDHOST}/ProvisionServer.sh"

if [ ! -f "${script_path}" ]
then
        /bin/echo "Error: Script not found at ${script_path}" >&2
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        /bin/echo "Error: Script at ${script_path} is not executable." >&2
        exit 1
fi

exec "${script_path}" "${REGION}" "${image}" "${server_size}" "${server_name}" "${user_data_path}" "${firewall_id}" "${snapshot_id}"

