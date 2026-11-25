#!/bin/sh
#: Name:        ProcessScalingEventsFromCron.sh
#: Purpose:     Cron-triggered guard script that prevents overlapping runs and invokes autoscaling event processing.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       ProcessScalingEventsFromCron.sh
#:              ProcessScalingEventsFromCron.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads installation state via ListFromDatastore.sh.
#:
#: Environment:
#:   HOME       Root directory of the autoscaler deployment toolkit
#:
#: Dependencies:
#:   - ${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh
#:   - ${HOME}/autoscaler/ProcessScalingEvents.sh
#:   - External binaries: echo, grep, cut, mkdir, rm
#:
#: Exit Codes:
#:   0          Scaling event cycle completed cleanly, or skipped (not installed / already running)
#:   1          Missing HOME environment, missing scaling script, or scaling execution failure
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

# Ensure runtime directory exists and acquire an atomic lockfile to prevent overlapping scaling runs
runtime_dir="${HOME}/runtime"
lockfile="${runtime_dir}/autoscalelock.file"

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

# Verify and execute the autoscaling event processor
scaling_script="${HOME}/autoscaler/ProcessScalingEvents.sh"
if [ ! -x "${scaling_script}" ]
then
        /bin/echo "Error: Autoscaling processor script missing or not executable at ${scaling_script}" >&2
        exit 1
fi

set +e
"${scaling_script}"
scaling_exit_code="$?"
set -e

if [ "${scaling_exit_code}" -ne 0 ]
then
        /bin/echo "Error: ProcessScalingEvents.sh failed with exit code ${scaling_exit_code}." >&2
        exit 1
fi

exit 0

