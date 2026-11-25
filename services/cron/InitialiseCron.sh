#!/bin/sh
#: Name:        InitialiseCron.sh
#: Purpose:     Generates and installs the root crontab schedule for an autoscaler machine.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseCron.sh
#:              InitialiseCron.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads home directory from /home/homedir.dat and deployment settings via ExtractConfigValue.sh.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#:   - ${HOME}/utilities/config/CheckBuildStyle.sh
#:   - ${HOME}/utilities/processing/RunServiceCommand.sh
#:   - External binaries: cat, echo, grep, cut, awk, rm, mktemp, crontab, shuf, nice, sleep
#:
#: Exit Codes:
#:   0          Root crontab generated, installed, and cron service restarted cleanly
#:   1          Missing /home/homedir.dat, missing config utilities, or crontab installation failure
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

# Resolve the autoscaler toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Error: Autoscaler home configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

# Verify required configuration helpers exist before building crontab
config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"
style_extractor="${HOME}/utilities/config/ExtractBuildStyleValues.sh"
style_checker="${HOME}/utilities/config/CheckBuildStyle.sh"

if [ ! -x "${config_extractor}" ] || [ ! -x "${style_extractor}" ] || [ ! -x "${style_checker}" ]
then
        /bin/echo "Error: One or more configuration helper scripts are missing or not executable under ${HOME}/utilities/config/" >&2
        exit 1
fi

# Build the new crontab in a temporary staging file before installing via crontab(1)
tmp_cron="$(/bin/mktemp)"
cleanup()
{
        /bin/rm -f "${tmp_cron}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Resolve timezone and multi-region settings from deployment configuration
MULTI_REGION="$("${config_extractor}" 'MULTIREGION')"
SERVER_TIMEZONE_CONTINENT="$("${config_extractor}" 'SERVERTIMEZONECONTINENT')"
SERVER_TIMEZONE_CITY="$("${config_extractor}" 'SERVERTIMEZONECITY')"

# Write global cron environment headers
{
        /bin/echo "MAILTO=''"
        /bin/echo "HOME=${HOME}"
        if [ -n "${SERVER_TIMEZONE_CONTINENT}" ] && [ -n "${SERVER_TIMEZONE_CITY}" ]
        then
                /bin/echo "TZ=:${SERVER_TIMEZONE_CONTINENT}/${SERVER_TIMEZONE_CITY}"
        fi
} > "${tmp_cron}"

# Every minute tasks
{
        /bin/echo "*/1 * * * * ${HOME}/utilities/security/AuditSSHConnections.sh"
        /bin/echo "*/1 * * * * /bin/sleep 30 && ${HOME}/utilities/processing/UpdateIPs.sh"
        /bin/echo "*/1 * * * * ${HOME}/services/cron/SetupFirewallFromCron.sh"
        /bin/echo "*/1 * * * * ${HOME}/utilities/housekeeping/RemoveExpiredLocks.sh"
        /bin/echo "*/1 * * * * ${HOME}/utilities/status/MonitorForOverload.sh"
        /bin/echo "*/1 * * * * ${HOME}/utilities/status/CheckNetworkManagerStatus.sh"
        /bin/echo "*/1 * * * * ${HOME}/services/cron/PerformEmergencyRestorationFromCron.sh"
} >> "${tmp_cron}"

if [ "${MULTI_REGION}" = "1" ]
then
        /bin/echo "*/1 * * * * ${HOME}/services/dbaas/AdjustDBaaSFirewall.sh" >> "${tmp_cron}"
fi

# Every 2 minutes tasks
{
        #/bin/echo "*/2 * * * * ${HOME}/services/cron/PerformScalingFromCron.sh"
        /bin/echo "*/2 * * * * ${HOME}/services/cron/ProcessScalingEventsFromCron.sh"
        /bin/echo "*/2 * * * * ${HOME}/services/cron/MonitorForWebsiteDeathFromCron.sh"
} >> "${tmp_cron}"

# Every 3 minutes tasks
{
        #/bin/echo "*/3 * * * * ${HOME}/services/cron/DeadOrAliveFromCron.sh"
} >> "${tmp_cron}"

# Every 5 minutes tasks
{
        /bin/echo "*/5 * * * * /bin/sleep 23 && ${HOME}/services/security/firewall/MonitorFirewall.sh"
        /bin/echo "*/5 * * * * ${HOME}/autoscaler/RecordNumberOfWebserversRunning.sh"
} >> "${tmp_cron}"

# Every 10 minutes tasks
{
        /bin/echo "*/10 * * * * ${HOME}/utilities/security/EnforcePermissions.sh"
        /bin/echo "*/10 * * * * ${HOME}/utilities/status/MonitorCron.sh"
} >> "${tmp_cron}"

# Hourly, daily, and maintenance tasks
{
        /bin/echo "@hourly ${HOME}/utilities/status/LoadMonitoring.sh"
        /bin/echo "30 3 * * * ${HOME}/utilities/housekeeping/RemoveExpiredLogs.sh"
        /bin/echo "22 4 * * * ${HOME}/utilities/software/UpdateSoftware.sh"
        /bin/echo "44 4 * * * ${HOME}/installation/UpdateAndUpgrade.sh"
        /bin/echo "@daily ${HOME}/utilities/housekeeping/ArchiveErrorLogs.sh"
} >> "${tmp_cron}"

# Reboot tasks
{
        /bin/echo "@reboot ${HOME}/utilities/housekeeping/RemoveExpiredLocks.sh reboot"
        /bin/echo "@reboot ${HOME}/utilities/status/LoadMonitoring.sh 'reboot'"
        /bin/echo "@reboot ${HOME}/utilities/status/CheckNetworkManagerStatus.sh"
        /bin/echo "@reboot ${HOME}/services/datastore/config/ActivateConfigDatastore.sh"
} >> "${tmp_cron}"

datastore_style="$("${style_extractor}" "DATASTORECONFIGSTYLE" | /usr/bin/awk -F':' '{print $NF}')"
case "${datastore_style}" in
        lightweight)
                /bin/echo "@reboot ${HOME}/services/datastore/config/ActivateConfigDatastoreLightweight.sh" >> "${tmp_cron}"
                ;;
        heavyweight)
                /bin/echo "@reboot ${HOME}/services/datastore/config/ActivateConfigDatastoreHeavyweight.sh" >> "${tmp_cron}"
                ;;
esac

# Optional scheduled virus scan based on build style
if [ "$("${style_checker}" 'VIRUSSCANNER:')" = "1" ]
then
        periodicity="$("${style_extractor}" 'VIRUSSCANNER' | /usr/bin/awk -F':' '{print $NF}')"
        case "${periodicity}" in
                daily|weekly|monthly)
                        /bin/echo "@${periodicity} /bin/sleep \$(/usr/bin/shuf -i1-1000 -n1) && /usr/bin/nice -n 15 ${HOME}/utilities/security/VirusScan.sh" >> "${tmp_cron}"
                        ;;
        esac
fi

# Install the staged crontab safely via crontab(1)
if ! /usr/bin/crontab "${tmp_cron}"
then
        /bin/echo "Error: Failed to install root crontab from staging file." >&2
        exit 1
fi

# Restart the cron daemon to apply schedule changes cleanly
service_runner="${HOME}/utilities/processing/RunServiceCommand.sh"
if [ -x "${service_runner}" ]
then
        "${service_runner}" "cron" restart
else
        /bin/echo "Error: Service runner missing or not executable at ${service_runner}" >&2
        exit 1
fi

exit 0

