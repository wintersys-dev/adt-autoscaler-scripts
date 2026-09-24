#!/bin/sh

if ( [ -f ${HOME}/home/${SERVER_USER}/runtime/scaling/scaling.conf-incoming ] )
then

#need to read number of webservers that are running for this autoscaler
#get the number of webservers that I expect to be running for this autoscaler
#shutdown webservers that need to be shutdown
#build webservers that need to be added
  echo "Scaling event"
fi
