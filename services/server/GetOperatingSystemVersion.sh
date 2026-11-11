#!/bin/sh
###################################################################################
# @file        GetOperatingSystemVersion.sh
# @brief       Resolves and formats the target operating system image string.
# @author      Peter Winter
# @date        13/06/2026
# @version     1.0
#
# @details     This script retrieves the configured operating system type, version,
#              and cloud provider metadata from the environment configuration, then
#              outputs the standardized OS image identifier required by the active
#              cloud host API.
#
# @param       None
#
# @env         HOME  [Required] Base directory containing configuration utilities
#                    and cloud provider marker files.
#
# @dependencies
#              - ${HOME}/utilities/config/ExtractConfigValue.sh to retrieve configuration keys.
#              - ${HOME}/utilities/software/GetOSName.sh to resolve Debian release codenames.
#
# @security    
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#              - Enforces strict input and execution permission checks before invoking downstream utilities.
#
# @exit        0  Success: Operating system image string resolved and printed cleanly.
# @exit        1  Failure: Missing configuration values, unreadable or non-executable utilities,
#                 or unsupported OS/provider combination encountered.
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
#########################################################################################
#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi


extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -f "${extract_script}" ] || [ ! -x "${extract_script}" ]
then
    /bin/echo "Error: Configuration utility missing or not executable at ${extract_script}" >&2
    exit 1
fi

set +e
BUILDOS="$("${extract_script}" 'BUILDOS')"
exit_code=$?
set -e
if [ ${exit_code} -ne 0 ] || [ -z "${BUILDOS}" ]
then
    /bin/echo "Error: Failed to retrieve BUILDOS configuration value." >&2
    exit 1
fi

set +e
BUILDOS_VERSION="$("${extract_script}" 'BUILDOSVERSION')"
exit_code=$?
set -e
if [ ${exit_code} -ne 0 ] || [ -z "${BUILDOS_VERSION}" ]
then
    /bin/echo "Error: Failed to retrieve BUILDOSVERSION configuration value." >&2
    exit 1
fi

set +e
CLOUDHOST="$("${extract_script}" 'CLOUDHOST')"
exit_code=$?
set -e
if [ ${exit_code} -ne 0 ] || [ -z "${CLOUDHOST}" ]
then
    /bin/echo "Error: Failed to retrieve CLOUDHOST configuration value." >&2
    exit 1
fi

if [ -f "${HOME}/DROPLET" ] || [ "${CLOUDHOST}" = "digitalocean" ]
then
    BUILDOS_VERSION="$(/bin/echo "${BUILDOS_VERSION}" | /bin/sed 's/\./-/g')"
    if [ "${BUILDOS}" = "ubuntu" ]
    then
        /bin/echo "ubuntu-${BUILDOS_VERSION}-x64"
        exit 0
    elif [ "${BUILDOS}" = "debian" ]
    then
        /bin/echo "debian-${BUILDOS_VERSION}-x64"
        exit 0
    fi
fi

if [ -f "${HOME}/EXOSCALE" ] || [ "${CLOUDHOST}" = "exoscale" ]
then
    if [ "${BUILDOS}" = "ubuntu" ]
    then
        /bin/echo "Linux Ubuntu ${BUILDOS_VERSION} LTS 64-bit"
        exit 0
    elif [ "${BUILDOS}" = "debian" ]
    then
        os_name_script="${HOME}/utilities/software/GetOSName.sh"
        if [ ! -f "${os_name_script}" ] || [ ! -x "${os_name_script}" ]
        then
            /bin/echo "Error: OS name utility missing or not executable at ${os_name_script}" >&2
            exit 1
        fi

        set +e
        os_name="$("${os_name_script}" | /bin/sed -e "s/\b\(.\)/\u\1/g")"
        exit_code=$?
        set -e
        if [ ${exit_code} -ne 0 ] || [ -z "${os_name}" ]
        then
            /bin/echo "Error: Failed to resolve Debian OS codename." >&2
            exit 1
        fi

        # At the current time (2026) 14 and 15 are here for futureproofing, not for use
        case "${BUILDOS_VERSION}" in
            12|13|14|15)
                /bin/echo "Linux Debian ${BUILDOS_VERSION} (${os_name}) 64-bit"
                exit 0
                ;;
        esac
    fi
fi

if [ -f "${HOME}/LINODE" ] || [ "${CLOUDHOST}" = "linode" ]
then
    if [ "${BUILDOS}" = "ubuntu" ]
    then
        /bin/echo "linode/ubuntu${BUILDOS_VERSION}"
        exit 0
    elif [ "${BUILDOS}" = "debian" ]
    then
        /bin/echo "linode/debian${BUILDOS_VERSION}"
        exit 0
    fi
fi

if [ -f "${HOME}/VULTR" ] || [ "${CLOUDHOST}" = "vultr" ]
then
    if [ "${BUILDOS}" = "ubuntu" ]
    then
        /bin/echo "Ubuntu ${BUILDOS_VERSION} LTS x64"
        exit 0
    elif [ "${BUILDOS}" = "debian" ]
    then
        /bin/echo "Debian ${BUILDOS_VERSION} x64"
        exit 0
    fi
fi

/bin/echo "Error: Unsupported CLOUDHOST (${CLOUDHOST}), BUILDOS (${BUILDOS}), or BUILDOSVERSION (${BUILDOS_VERSION})." >&2
exit 1

