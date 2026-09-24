#Move this bit to a cron script
if ( [ -f ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE ] )
then
        if ( [ "`/usr/bin/find ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE -mmin +10 -type f`" != "" ] )
        then
                /bin/rm ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE
        else
                if ( [ -f ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE ] )
                then
                        exit
                fi
        fi
else
        /bin/touch ${HOME}/runtime/WEBSITE_MONITORING_ACTIVE
fi
