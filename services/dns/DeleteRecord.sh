
if ( [ "${1}" = "" ] )
then
    status "Error: One arguments argument is required."
    status "Usage: $0 <record_id>" 
    exit 1
fi

export HOME="`/bin/cat /home/homedir.dat`"

record_id="${1}"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

if ( [ ! -d ${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool} ] )
then
  orchestration_tool="api"
fi

${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecord.sh ${record_id} 

