#!/bin/sh
###################################################################################
# @file        update_database_firewall.sh
# @brief       Updates the allow list configuration for a managed Linode PostgreSQL database.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script extracts the required infrastructure authentication tokens,
#              validates the target database identity and allow-list parameters, and
#              invokes the provider CLI client under a strict status monitoring block
#              to cleanly apply updated access rules to the designated PostgreSQL instance.
#
# @param       $1  [Required] The unique numerical or textual identifier of the target database.
# @param       $2  [Required] The allow-list configuration string or JSON payload for the database.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Restricts authorization lifetime by unsetting credentials immediately post-execution.
#
# @exit        0  Success: Target PostgreSQL database allow list updated cleanly.
# @exit        *  Failure: Missing arguments, unreadable base paths, or cascading 
#                 exit failures bubbling up from the provider API client.
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
        /bin/echo "Error: database_id and allow_list are required." >&2
        /bin/echo "Usage: $0  <database_id> <allow_list>" >&2
        exit 1
fi

database_id="${1}"
allow_list="${2}"

set -- "${database_id}"

OLD_IFS="${IFS}"
IFS=' '
for ip in ${allow_list} 
do
        [ -z "${ip}" ] && continue

        case "${ip}" in
                */*) cidr="${ip}" ;;
                *)   cidr="${ip}/32" ;;
        esac

        set -- "$@" --allow_list "${cidr}"
done
IFS="${OLD_IFS}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
VPC_IP_RANGE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE')"
set -e

set -- "$@" --allow_list "${VPC_IP_RANGE}"

if  [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)."  >&2
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set -- "$@" --allow_list "${VPC_IP_RANGE}"

set +e
/usr/local/bin/linode-cli --no-defaults databases postgresql-update "$@"
exit_code="$?"
set -e

unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli databases postgresql-update failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

/bin/echo "Success: Linode Database PostgreSQL Update for ${database_id} applied correctly."
exit 0

