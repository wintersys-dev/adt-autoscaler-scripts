#!/bin/sh
#: Name:        get_domains.sh
#: Purpose:     Retrieves all configured DNS domains from the Linode account via linode-cli.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       get_domains.sh
#:              get_domains.sh [-h|--help]
#:
#: Parameters:
#:   None       Fetches all domains under the authenticated Linode account and prints JSON array to stdout.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - /usr/local/bin/linode-cli
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Account DNS domain payload retrieved cleanly and printed to stdout
#:   *          Missing /home/homedir.dat, missing TOKEN, or bubbled CLI exit code
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
/usr/local/bin/linode-cli --no-defaults --json domains list
exit_code="$?"
set -e

unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli domains list failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

