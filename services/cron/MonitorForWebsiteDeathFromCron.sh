#!/bin/sh
#: Name:        MonitorForWebsiteDeathFromCron.sh
#: Purpose:     Cron-triggered guard script that prevents overlapping runs and invokes website health/death monitoring.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     2.0
#:
#: Usage:       MonitorForWebsiteDeathFromCron.sh
#:              MonitorForWebsiteDeathFromCron.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads installation state via ListFromDatastore.sh.
#:
#: Environment:
#:   HOME       Root directory of the autoscaler deployment toolkit
#:
#: Dependencies:
#:   - ${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh
#:   - ${HOME}/autoscaler/MonitorForWebsiteDeath.sh
#:   - External binaries: echo, grep, cut, find, mkdir, rm
#:
#: Exit Codes:
#:   0          Monitoring cycle completed cleanly, or skipped (not installed / already active)
#:   1          Missing HOME environment, missing monitor script, or monitor execution failure
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
        /bin/echo "Error: HOME environment variable is unset or invalid." >&2
        exit 1
fi

# Abort silently if the deployment has not completed initial installation
installed_flag="$("${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh" "config" "INSTALLED_SUCCESSFULLY")"
if [ -z "${installed_flag}" ]
then
        exit 0
fi

# Ensure runtime directory exists
runtime_dir="${HOME}/runtime"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

# Clear any stale active-monitoring flag older than 10 minutes
active_flag="${runtime_dir}/WEBSITE_MONITORING_ACTIVE"
if [ -f "${active_flag}" ]
then
        if [ -n "$(/usr/bin/find "${active_flag}" -mmin +10 -type f 2>/dev/null)" ]
        then
                /bin/rm -f "${active_flag}"
        else
                exit 0
        fi
fi

# Acquire atomic lockfiles for both active-monitoring state and execution mutex
lockfile="${runtime_dir}/websitedeath.file"

if ! (set -C; : > "${active_flag}") 2>/dev/null
then
        exit 0
fi

if ! (set -C; : > "${lockfile}") 2>/dev/null
then
        /bin/rm -f "${active_flag}"
        exit 0
fi

# Guarantee lockfile cleanup on normal exit or termination signals
cleanup()
{
        /bin/rm -f "${lockfile}" "${active_flag}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Verify and execute the website death monitoring script
monitor_script="${HOME}/autoscaler/MonitorForWebsiteDeath.sh"
if [ ! -x "${monitor_script}" ]
then
        /bin/echo "Error: Website monitoring script missing or not executable at ${monitor_script}" >&2
        exit 1
fi

set +e
"${monitor_script}"
monitor_exit_code="$?"
set -e

if [ "${monitor_exit_code}" -ne 0 ]
then
        /bin/echo "Error: MonitorForWebsiteDeath.sh failed with exit code ${monitor_exit_code}." >&2
        exit 1
fi

exit 0

