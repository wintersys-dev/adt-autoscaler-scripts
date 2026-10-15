export HOME="`/bin/cat /home/homedir.dat`"

#zone_id="${1}"
record_id="${1}"
#dns_username="${3}"
#dns_security_key="${4}"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
#${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecord.sh ${zone_id} ${record_id} ${dns_username} ${dns_security_key}

${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecord.sh ${record_id} 

