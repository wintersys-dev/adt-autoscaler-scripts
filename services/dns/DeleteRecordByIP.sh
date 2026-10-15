
export HOME="`/bin/cat /home/homedir.dat`"

website_url="${1}"
ip="${2}"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecordByIP.sh ${website_url} ${ip}
