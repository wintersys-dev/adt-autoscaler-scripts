#!/bin/sh
#: Name:        GetOperatingSystemVersion.sh
#: Purpose:     Resolves and outputs the cloud-provider-specific OS image identifier string.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       GetOperatingSystemVersion.sh
#:              GetOperatingSystemVersion.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads BUILDOS, BUILDOSVERSION, and CLOUDHOST from configuration.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/software/GetOSName.sh
#:   - External binaries: cat, echo, printf, grep, cut, sed, awk
#:
#: Exit Codes:
#:   0          Operating system image identifier resolved and printed cleanly
#:   1          Missing /home/homedir.dat, missing config values/utilities, or unsupported OS/provider
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

extract_script="${HOME}/utilities/config/ExtractConfigValue.sh"
if [ ! -f "${extract_script}" ] || [ ! -x "${extract_script}" ]
then
        /bin/echo "Error: Configuration utility missing or not executable at ${extract_script}" >&2
        exit 1
fi

set +e
BUILDOS="$("${extract_script}" 'BUILDOS')"
exit_code="$?"
set -e
if [ "${exit_code}" -ne 0 ] || [ -z "${BUILDOS}" ]
then
        /bin/echo "Error: Failed to retrieve BUILDOS configuration value." >&2
        exit 1
fi

set +e
BUILDOS_VERSION="$("${extract_script}" 'BUILDOSVERSION')"
exit_code="$?"
set -e
if [ "${exit_code}" -ne 0 ] || [ -z "${BUILDOS_VERSION}" ]
then
        /bin/echo "Error: Failed to retrieve BUILDOSVERSION configuration value." >&2
        exit 1
fi

set +e
CLOUDHOST="$("${extract_script}" 'CLOUDHOST')"
exit_code="$?"
set -e
if [ "${exit_code}" -ne 0 ] || [ -z "${CLOUDHOST}" ]
then
        /bin/echo "Error: Failed to retrieve CLOUDHOST configuration value." >&2
        exit 1
fi

if [ -f "${HOME}/DROPLET" ] || [ "${CLOUDHOST}" = "digitalocean" ]
then
        do_version="$(printf '%s\n' "${BUILDOS_VERSION}" | /bin/sed 's/\./-/g')"
        if [ "${BUILDOS}" = "ubuntu" ]
        then
                /bin/echo "ubuntu-${do_version}-x64"
                exit 0
        elif [ "${BUILDOS}" = "debian" ]
        then
                /bin/echo "debian-${do_version}-x64"
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
                raw_os_name="$("${os_name_script}")"
                exit_code="$?"
                set -e
                if [ "${exit_code}" -ne 0 ] || [ -z "${raw_os_name}" ]
                then
                        /bin/echo "Error: Failed to resolve Debian OS codename." >&2
                        exit 1
                fi

                os_name="$(printf '%s\n' "${raw_os_name}" | /usr/bin/awk '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')"

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


/bin/echo "Error: Unsupported CLOUDHOST (${CLOUDHOST}), BUILDOS (${BUILDOS}), or BUILDOSVERSION (${BUILDOS_VERSION})." >&2
exit 1

