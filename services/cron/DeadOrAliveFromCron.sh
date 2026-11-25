#!/bin/sh
#: Name:        DeadOrAlive.sh
#: Purpose:     Cron-triggered health check orchestrator on the autoscaler that evaluates and terminates dead reverse proxies and webservers.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       DeadOrAlive.sh
#:              DeadOrAlive.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads runtime configuration via ListFromDatastore.sh and ExtractConfigValue.sh.
#:
#: Environment:
#:   HOME       Root directory of the autoscaler deployment toolkit
#:
#: Dependencies:
#:   - ${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/autoscaler/DeadOrAliveReverseProxies.sh
#:   - ${HOME}/autoscaler/DeadOrAliveWebservers.sh
#:   - External binaries: echo, grep, cut, mkdir, rm
#:
#: Exit Codes:
#:   0          Health check cycle completed cleanly, or skipped (not installed / already running)
#:   1          Missing HOME environment or non-executable autoscaler sub-scripts
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

# Verify that HOME is set in the cron execution environment
if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "HOME environment variable is unset or invalid." >&2
        exit 1
fi

# Abort silently if the deployment has not completed initial installation
installed_flag="$("${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh" "config" "INSTALLED_SUCCESSFULLY")"
if [ -z "${installed_flag}" ]
then
        exit 0
fi

# Ensure runtime directory exists and acquire an atomic lockfile to prevent overlapping cron runs
runtime_dir="${HOME}/runtime"
lockfile="${runtime_dir}/deadoralivelock.file"

if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

if ! (set -C; : > "${lockfile}") 2>/dev/null
then
        exit 0
fi

# Guarantee lockfile removal on normal exit or termination signals
cleanup()
{
        /bin/rm -f "${lockfile}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Retrieve reverse proxy count from deployment configuration
NO_REVERSE_PROXIES="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'NOREVERSEPROXIES')"

# Evaluate reverse proxy health if reverse proxies are enabled in this deployment
if [ -n "${NO_REVERSE_PROXIES}" ] && [ "${NO_REVERSE_PROXIES}" != "0" ]
then
        rp_script="${HOME}/autoscaler/DeadOrAliveReverseProxies.sh"
        if [ ! -x "${rp_script}" ]
        then
                /bin/echo "Error: Reverse proxy health check script missing or not executable at ${rp_script}" >&2
                exit 1
        fi

        set +e
        "${rp_script}"
        rp_exit_code="$?"
        set -e

        if [ "${rp_exit_code}" -ne 0 ]
        then
                /bin/echo "Error: DeadOrAliveReverseProxies.sh failed with exit code ${rp_exit_code}." >&2
        fi
fi

# Evaluate webserver health
ws_script="${HOME}/autoscaler/DeadOrAliveWebservers.sh"
if [ ! -x "${ws_script}" ]
then
        /bin/echo "Error: Webserver health check script missing or not executable at ${ws_script}" >&2
        exit 1
fi

set +e
"${ws_script}"
ws_exit_code="$?"
set -e

if [ "${ws_exit_code}" -ne 0 ]
then
        /bin/echo "Error: DeadOrAliveWebservers.sh failed with exit code ${ws_exit_code}." >&2
        exit 1
fi

exit 0


