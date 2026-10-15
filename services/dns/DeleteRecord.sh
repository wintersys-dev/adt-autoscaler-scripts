export HOME="`/bin/cat /home/homedir.dat`"

auth_key="${3}"
sub_domain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domain_url="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/AddRecord.sh ${auth_key} ${sub_domain} ${domain_url} ${ip} 
