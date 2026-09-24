#set -x

REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
webserver_public_ips="`${HOME}/services/server/GetServerIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}" ${CLOUDHOST}`"
webserver_ips="`${HOME}/services/server/GetServerPrivateIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}" ${CLOUDHOST}`"

autoscaler_no="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"


if ( [ -f ${HOME}/runtime/scaling/scaling.conf-incoming ] )
then
        required_no_webservers="`/bin/grep "Autoscaler ${autoscaler_no}" ${HOME}/runtime/scaling/scaling.conf-incoming | /usr/bin/awk '{print $7}'`"
else
	exit
fi

webserver_names=""
for ip in ${webserver_public_ips}
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
no_webservers_to_destroy=""
no_webservers_to_provision=""

if ( [ "${no_webservers_delta}" -lt "0" ] )
then
        no_webservers_to_destroy="`/bin/echo ${no_webservers_delta} | /bin/sed 's/^-//'`"
else
        no_webservers_to_provision="${no_webservers_delta}"
fi

if ( [ "${no_webservers_to_destroy}" != "" ] )
then
        active_webservers="`/bin/ls ${HOME}/runtime/scaling/active_scaled_webservers/public_ips`"
        webservers_to_destroy_ips="`/bin/echo "${active_webservers}" | /usr/bin/tr '\n' ' ' | /usr/bin/cut -d' ' -f1-${no_webservers_to_destroy}`"
        for webserver_to_destroy_ip in ${webservers_to_destroy_ips}
        do
                ${HOME}/autoscaler/RemoveIPFromDNS.sh ${webserver_to_destroy_ip}
                ${HOME}/services/server/DestroyServer.sh ${webserver_to_destroy_ip} ${CLOUDHOST}
        done
fi

if ( [ "${no_webservers_to_provision}" != "" ] )
then
    provisioned_webserver_no="0"
	pids=""
	/bin/rm ${HOME}/runtime/scaling/SCALING_ENABLED
	
	while ( [ "${provisioned_webserver_no}" -le "`/usr/bin/expr ${no_webservers_to_provision} - 1`" ] )
	do
		provisioned_webserver_no="`/usr/bin/expr ${provisioned_webserver_no} + 1`"
		${HOME}/autoscaler/BuildWebserver.sh ${provisioned_webserver_no} &
		pids="${pids} $!"
  		/bin/sleep 10
	done
	
	for pid in ${pids}
	do
		wait ${pid}
	done
	
	/bin/touch ${HOME}/runtime/scaling/SCALING_ENABLED

fi

if ( [ -f ${HOME}/runtime/scaling/scaling.conf-incoming ] )
then
	/bin/mv ${HOME}/runtime/scaling/scaling.conf-incoming ${HOME}/runtime/scaling/scaling.conf
fi

