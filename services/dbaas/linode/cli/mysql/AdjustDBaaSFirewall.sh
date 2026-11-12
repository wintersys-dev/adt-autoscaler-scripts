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


if [ -z "${1}" ] || [ -z "${1}" ] 
then
        /bin/echo "Error: database_id and allow_list are required" >&2
        /bin/echo "Usage: $0 <database_id> <allow_list>" >&2
        exit 1
fi

database_id="${1}"
allow_list="${2}"

set +e
TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'TOKEN')"
set -e

if  [ -z "${TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (TOKEN)."  >&2
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
/usr/local/bin/linode-cli databases mysql-update ${database_id} ${allow_list} --no-defaults
exit_code="$?"
set -e

unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: linode-cli databases mysql-update failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

status "Success: Linode Database MySQL Update applied correctly"
exit 0
