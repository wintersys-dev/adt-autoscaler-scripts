#!/bin/sh
######################################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : Given a record id this will delete a DNS A record
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
set -e

if ( [ "${1}" = "" ] )
then
    status "Error: One arguments argument is required."
    status "Usage: $0 <record_id>" 
    exit 1
fi

export HOME="`/bin/cat /home/homedir.dat`"

record_id="${1}"

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"

if ( [ ! -d ${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool} ] )
then
  orchestration_tool="api"
fi

${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/DeleteRecord.sh ${record_id} 

