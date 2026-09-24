#!/bin/sh

if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "config" "INSTALLED_SUCCESSFULLY"`" = "" ] )
then
	exit
fi

CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
headfile="`${HOME}/autoscaler/SelectHeadFile.sh`"
stalled_webserver_build_ips="`/usr/bin/find ${HOME}/runtime/POTENTIAL_STALLED_BUILD:* -mmin +30 -type f | /usr/bin/awk -F':' '{print $NF}'`"

#Any machine that takes longer than 30 minutes to build is considered a stalled build and should be destroyed
for stalled_webserver_build_ip in ${stalled_webserver_build_ips}
do
        ${HOME}/services/server/DestroyServer.sh ${stalled_webserver_build_ip} ${CLOUDHOST}
done

active_webserver_ips="`/bin/ls ${HOME}/runtime/scaling/active_scaled_webservers/private_ips`"

for active_webserver_ip in ${active_webserver_ips}
do
	${HOME}/utilities/status/CheckWebsiteOnlineStatus.sh ${active_webserver_ip}/${headfile}
done


