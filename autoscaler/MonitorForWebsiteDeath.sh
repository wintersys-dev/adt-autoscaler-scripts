#!/bin/sh

#set -x

HOME="`/bin/cat /home/homedir.dat`"
CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"

check_if_webserver_online()
{
        active_webserver_ip="${1}"
        headfile="`${HOME}/autoscaler/SelectHeadFile.sh`"
        active_webserver_public_ip="`${HOME}/services/server/GetServerPublicIPAddressByIP.sh ${active_webserver_ip} ${CLOUDHOST}`"

        count="0"
        while ( [ "${count}" -lt "5" ] && [ "`${HOME}/utilities/status/CheckWebsiteOnlineStatus.sh ${active_webserver_ip}/${headfile}`" = "failure" ] )
        do
                count="`/usr/bin/expr ${count} + 1`"
        done
        online="success"
        if ( [ "${count}" != "0" ] && [ "`${HOME}/utilities/status/CheckWebsiteOnlineStatus.sh ${active_webserver_ip}/${headfile}`" = "failure" ] )
        then
                
                active_webserver_public_ip="`${HOME}/services/server/GetServerPublicIPAddressByIP.sh ${active_webserver_ip} ${CLOUDHOST}`"

                if ( [ -f ${HOME}/runtime/scaling/active_scaled_webservers/public_ips/${active_webserver_public_ip} ] )
                then
                        /bin/rm ${HOME}/runtime/scaling/active_scaled_webservers/public_ips/${active_webserver_public_ip}
                fi
                
                if ( [ -f ${HOME}/runtime/scaling/active_scaled_webservers/private_ips/${active_webserver_ip} ] )
                then
                        /bin/rm ${HOME}/runtime/scaling/active_scaled_webservers/private_ips/${active_webserver_ip}
                fi
                ${HOME}/autoscaler/RemoveIPFromDNS.sh ${active_webserver_public_ip}
                ${HOME}/services/server/DestroyServer.sh ${active_webserver_public_ip} ${CLOUDHOST}

                if ( [ "`${HOME}/utilities/config/ExtractConfigValue.sh 'DATABASEINSTALLATIONTYPE'`" = "DBaaS" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDMACHINEVPC:0`" = "1" ] )
                then
                        ${HOME}/services/dbaas/AdjustDBaaSFirewall.sh ${public_ip_address}
                fi
                online="failure"
        fi

        if ( [ "${online}" = "success" ] )
        then
                dns_ips="`${HOME}/autoscaler/GetDNSIPs.sh`"
                if ( [ "`/bin/echo ${dns_ips} | /bin/grep ${active_webserver_public_ip}`" = "" ] )
                then
                        ${HOME}/autoscaler/AddIPToDNS.sh ${active_webserver_public_ip}
                fi
        fi
}

if ( [ -f ${HOME}/runtime/POTENTIAL_STALLED_BUILD:* ] )
then
        stalled_webserver_build_ips="`/usr/bin/find ${HOME}/runtime/POTENTIAL_STALLED_BUILD:* -mmin +30 -type f | /usr/bin/awk -F':' '{print $NF}'`"

        #Any machine that takes longer than 30 minutes to build is considered a stalled build and should be destroyed
        for stalled_webserver_build_ip in ${stalled_webserver_build_ips}
        do
                ${HOME}/services/server/DestroyServer.sh ${stalled_webserver_build_ip} ${CLOUDHOST}
        done
fi

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


