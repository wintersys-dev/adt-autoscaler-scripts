#!/bin/sh
########################################################################################
# Description: This script is called regularly from cron and performs the autoscaling.
# Author: Peter Winter
# Date: 12/01/2017
########################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################################
#########################################################################################
#set -x
#If we are here without being fully installed, exit
if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "INSTALLED_SUCCESSFULLY"`" = "" ] )
then
	exit
fi

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

if ( [ ! -f ${lockfile} ] )
then
	/usr/bin/touch ${lockfile}
	${HOME}/autoscaler/MonitoForWebsiteDeath.sh
	/bin/rm ${lockfile}
fi
