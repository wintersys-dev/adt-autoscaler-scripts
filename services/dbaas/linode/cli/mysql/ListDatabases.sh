#!/bin/sh

#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ]
then
        /bin/echo "Error: Database label argument is required." >&2
        /bin/echo "Usage: $0  <label>" >&2
        exit 1
fi

label="${1}"

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

unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ] || [ -z "${raw_mysql_list}" ]
then
        /bin/echo "Error: linode-cli databases mysql-list failed with exit code ${exit_code}." >&2
        exit 1
fi

exit 0


