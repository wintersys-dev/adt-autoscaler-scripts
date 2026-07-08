#!/bin/sh
######################################################################################################
# Description: This script will install the exo utility
# Author: Peter Winter
# Date: 17/01/2017
#######################################################################################################
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
#######################################################################################################
#######################################################################################################
#set -x

if ( [ "${1}" != "" ] )
then
	buildos="${1}"
fi

if ( [ "${buildos}" = "" ] )
then
	BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
else 
	BUILDOS="${buildos}"
fi

manager=""
options=""
tail_options=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt" ] )
then
	manager="/usr/bin/apt"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
	manager="/usr/bin/apt-get"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "nala" ] )
then
	manager="${HOME}/installation/nala_wrapper.sh"
	tail_options="-y"
fi

export DEBIAN_FRONTEND=noninteractive
install_command="${manager} ${options} install " 

count="0"
while ( [ ! -f /usr/bin/exo ] && [ "${count}" -lt "5" ] )
do
	if ( [ "${BUILDOS}" = "ubuntu" ] )
	then
	    if ( [ "`/bin/grep "^CLOUDCLITOOL:*" ${HOME}/runtime/software.dat | /bin/grep CLOUDCLITOOL:exo:repo`" != "" ] )
		then
			/usr/bin/curl -fsSL https://raw.githubusercontent.com/exoscale/cli/master/install-latest.sh | /bin/sh	
		elif ( [ "`/bin/grep "^CLOUDCLITOOL:*" ${HOME}/runtime/software.dat | /bin/grep CLOUDCLITOOL:exo:source`" != "" ] )
		then
			${install_command} build-essential  ${tail_options}
			${HOME}/installation/InstallGo.sh ${BUILDOS}
			if ( [ ! -d /opt/exoscale ] )
			then
				/bin/mkdir /opt/exoscale
			fi
			cd /opt/exoscale
			${HOME}/services/git/GitClone.sh "github" "" "exoscale" "cli" ""
			cd /opt/exoscale/cli
			/usr/bin/make build
			/bin/ln -s /opt/exoscale/cli/bin/exo /usr/bin/exo
			cd ${HOME}
		fi
	fi

	if ( [ "${BUILDOS}" = "debian" ] )
	then
	    if ( [ "`/bin/grep "^CLOUDCLITOOL:*" ${HOME}/runtime/software.dat | /bin/grep CLOUDCLITOOL:exo:repo`" != "" ] )
		then
			/usr/bin/curl -fsSL https://raw.githubusercontent.com/exoscale/cli/master/install-latest.sh | /bin/sh	
		elif ( [ "`/bin/grep "^CLOUDCLITOOL:*" ${HOME}/runtime/software.dat | /bin/grep CLOUDCLITOOL:exo:source`" != "" ] )
		then
			${install_command} build-essential  ${tail_options}
			${HOME}/installation/InstallGo.sh ${BUILDOS}
			if ( [ ! -d /opt/exoscale ] )
			then
				/bin/mkdir /opt/exoscale
			fi
			cd /opt/exoscale
			${HOME}/services/git/GitClone.sh "github" "" "exoscale" "cli" ""
			cd /opt/exoscale/cli
			/usr/bin/make build
			/bin/ln -s /opt/exoscale/cli/bin/exo /usr/bin/exo
			cd ${HOME}
		fi
	fi
	count="`/usr/bin/expr ${count} + 1`"
done

if ( [ ! -x /usr/bin/exo ] && [ "${count}" = "5" ] )
then
	${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR EXO" "I believe that exo hasn't installed correctly, please investigate" "ERROR"
else
	/bin/touch ${HOME}/runtime/installedsoftware/InstallExo.sh				
fi
