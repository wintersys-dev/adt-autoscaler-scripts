#set -x

REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
webserver_ips="`${HOME}/services/server/GetServerIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}" ${CLOUDHOST}`"
autoscaler_no="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"

webserver_names=""
for ip in ${webserver_ips}
do
        webserver_names="${webserver_names} `${HOME}/services/server/GetServerName.sh ${ip} ${CLOUDHOST} | /bin/grep -v '\-init\-'`"
done

no_running_webservers="0"
for webserver_name in ${webserver_names}
do
        webserver_no="`/bin/echo ${webserver_name} | /bin/sed -e "s/.*${BUILD_IDENTIFIER}-//g" -e 's/-.*//g'`"
        if ( [ "${webserver_no}" = "${autoscaler_no}" ] )
        then
                no_running_webservers="`/usr/bin/expr ${no_running_webservers} + 1`"
        fi
done

/bin/echo "${no_running_webservers}"
