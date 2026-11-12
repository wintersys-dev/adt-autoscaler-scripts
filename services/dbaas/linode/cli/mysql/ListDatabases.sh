#!/bin/sh
###################################################################################
# @file        ListDatabases.sh
# @brief       Lists all managed Linode MySQL database instances in JSON format.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script resolves the active toolkit environment, retrieves the
#              required Linode API authentication token, and invokes the provider
#              CLI client under a strict status monitoring block to output the
#              full inventory of managed MySQL databases in JSON format.
#
# @env         HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/utilities/config/ExtractConfigValue.sh
#              - external dependencies: cat, echo, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Restricts authorization lifetime by unsetting credentials immediately post-execution.
#
# @exit        0  Success: Managed MySQL database inventory retrieved and printed to stdout.
# @exit        *  Failure: Unreadable base paths, missing authentication token, or cascading
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

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)." >&2
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
/usr/local/bin/linode-cli databases mysql-list --no-defaults --json
exit_code="$?"
set -e

# Unset token instantly to maintain high security-isolation states
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli databases mysql-list failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0



