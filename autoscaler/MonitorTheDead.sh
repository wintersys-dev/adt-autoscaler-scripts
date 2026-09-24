#!/bin/sh

check_if_webserver_online()
{
	active_webserver_ip="${1}"
	headfile="`${HOME}/autoscaler/SelectHeadFile.sh`"
	
	count="0"
	while ( [ "${count}" -lt "5" ] && [ "`${HOME}/utilities/status/CheckWebsiteOnlineStatus.sh ${active_webserver_ip}/${headfile}`" = "failure" ] )
	do
		count="`/usr/bin/expr ${count} + 1`"
	done
	if ( [ "${count}" != "0" ] && [ "`${HOME}/utilities/status/CheckWebsiteOnlineStatus.sh ${active_webserver_ip}/${headfile}`" = "failure" ] )
	then
		/bin/echo "failure"
	else
		/bin/echo "success"
	fi
}

if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "config" "INSTALLED_SUCCESSFULLY"`" = "" ] )
then
	exit
fi

CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
stalled_webserver_build_ips="`/usr/bin/find ${HOME}/runtime/POTENTIAL_STALLED_BUILD:* -mmin +30 -type f | /usr/bin/awk -F':' '{print $NF}'`"

#Any machine that takes longer than 30 minutes to build is considered a stalled build and should be destroyed
for stalled_webserver_build_ip in ${stalled_webserver_build_ips}
do
        ${HOME}/services/server/DestroyServer.sh ${stalled_webserver_build_ip} ${CLOUDHOST}
done

active_webserver_ips="`/bin/ls ${HOME}/runtime/scaling/active_scaled_webservers/private_ips`"

for active_webserver_ip in ${active_webserver_ips}
do
	check_if_webserver_online ${active_webserver_ip} &
done


