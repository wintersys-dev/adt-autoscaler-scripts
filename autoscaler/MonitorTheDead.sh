


#If we are trying to build a webserver before the toolkit has been fully installed, we don't want to do anything, so exit
if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "config" "INSTALLED_SUCCESSFULLY"`" = "" ] )
then
	exit
fi

CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
stalled_webserver_build_ips="`/usr/bin/find ${HOME}/runtime/POTENTIAL_STALLED_BUILD:* -mmin +1 -type f | /usr/bin/awk -F':' '{print $NF}'`"

for stalled_webserver_build_ip in ${stalled_webserver_build_ips}
do
        ${HOME}/services/server/DestroyServer.sh ${stalled_webserver_build_ip} ${CLOUDHOST}
done
