#!/bin/sh

#set -x

website_url="${1}"
ip="${2}"


export HOME="`/bin/cat /home/homedir.dat`"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/GetRecordID.sh ${website_url} ${ip}
