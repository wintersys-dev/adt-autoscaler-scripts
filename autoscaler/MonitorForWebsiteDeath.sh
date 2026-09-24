#!/bin/sh

#set -x

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
                active_webserver_public_ip="`${HOME}/services/server/GetServerPublicIPAddressByIP.sh ${active_webserver_ip} ${CLOUDHOST}`"
                ${HOME}/services/server/DestroyServer.sh ${active_webserver_public_ip} ${CLOUDHOST}
                if ( [ "`${HOME}/utilities/config/ExtractConfigValue.sh 'DATABASEINSTALLATIONTYPE'`" = "DBaaS" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDMACHINEVPC:0`" = "1" ] )
                then
                        ${HOME}/services/dbaas/AdjustDBaaSFirewall.sh ${public_ip_address}
                fi
        fi
}

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
        pids="${pids} $!"
        /bin/sleep 5

        for pid in ${pids}
        do
                wait ${pid}
        done

        if ( [ -f ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE ] )
        then
                /bin/rm ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE
        fi
done


