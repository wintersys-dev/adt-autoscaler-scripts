#!/bin/sh

zone_id="${1}"
website_url="${2}"
ip="${3}"
dns_username="${4}"
dns_security_key="${5}"


export HOME="`/bin/cat /home/homedir.dat`"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/GetRecordID.sh ${zone_id} ${website_url} ${ip} ${dns_username} ${dns_security_key}
