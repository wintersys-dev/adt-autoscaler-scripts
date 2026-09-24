#set -x

REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
webserver_ips="`${HOME}/services/server/GetServerIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}" ${CLOUDHOST}`"
autoscaler_no="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"


if ( [ -f ${HOME}/runtime/scaling/scaling.conf-incoming ] )
then
        required_no_webservers="`/bin/grep "Autoscaler ${autoscaler_no}" ${HOME}/runtime/scaling/scaling.conf-incoming | /usr/bin/awk '{print $7}'`"
fi

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

no_webservers_delta="`/usr/bin/expr ${required_no_webservers} - ${no_running_webservers}`"

