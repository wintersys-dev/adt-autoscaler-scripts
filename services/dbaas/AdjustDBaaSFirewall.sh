#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 13/06/2021
# Description : This will tighten the DBaaS firewall so that the DBaaS system is only
# accessible to IP addresses that we control (our fleet of webservers basically)
#######################################################################################
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
########################################################################################
########################################################################################
#set -x
ip_to_delete="${1}"

BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'REGION'`"
CLOUDHOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'CLOUDHOST'`"
MULTI_REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'MULTIREGION'`"
PRIMARY_REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PRIMARYREGION'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
DATABASE_DBAAS_INSTALLATION_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DATABASE_DBAAS_INSTALLATION_TYPE'`"


database_engine="mysql"
if ( [ "`/bin/echo ${DATABASE_DBAAS_INSTALLATION_TYPE} | /bin/grep 'Postgres'`" != "" ] )
then
        database_engine="postgres"
fi

orchestration_tool="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "ORCHESTRATION_TOOL" | /usr/bin/awk -F':' '{print $NF}'`"

multi_region_ips=""

if ( [ ! -d ${HOME}/runtime/dbaas_allowed_ips ] )
then
        /bin/mkdir -p ${HOME}/runtime/dbaas_allowed_ips
fi

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" != "1" ] )
then
        multi_region_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-multi-region"
        multi_region_ips="`${HOME}/services/datastore/operations/ListFromDatastore.sh "multi-region" "dbaas_ips/*" | /usr/bin/awk -F'/' '{print $NF}'`"

        /bin/touch ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat

        modified="no"
        for ip in ${multi_region_ips}
        do
                if ( [ "`/bin/grep ${ip} ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat`" = "" ] )
                then
                        /bin/echo "${ip}" >> ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat
                        modified="yes"
                fi
                for ip in `/bin/cat ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat`
                do
                        if ( [ "`/bin/echo ${multi_region_ips} | /bin/grep ${ip}`" = "" ] )
                        then
                                /bin/sed -i "#${ip}#d"  ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat
                                modified="yes"
                        fi
                done
        done

        if ( [ "${modified}" = "no" ] )
        then
                exit
        fi
fi

dbaas="`${HOME}/utilities/config/ExtractConfigValues.sh "DATABASEDBaaSINSTALLATIONTYPE" "stripped"`"
label="`${HOME}/utilities/config/ExtractConfigValues.sh "DATABASEDBaaSINSTALLATIONTYPE" "stripped" | /usr/bin/awk '{print $7}'`"
database_id="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | /usr/bin/jq '.[] | select(.label | contains ("'${label}'")) | .id'`"

if ( [ "${database_id}" = "" ] )
then
  database_id="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq '.[] | select(.label | contains ("'${label}'")) | .id'`"
fi

webserver_ips="`${HOME}/services/server/GetServerPublicIPAddresses.sh "ws-${REGION}-${BUILD_IDENTIFIER}"`"
database_ips="`${HOME}/services/server/GetServerPublicIPAddresses.sh "db-${REGION}-${BUILD_IDENTIFIER}"`"
ipaddresses="${webserver_ips} ${database_ips}"

if ( [ "${multi_region_ips}" != "" ] )
then
  for ip in ${multi_region_ips}
  do
    ipaddresses="${ipaddresses} ${ip}"
  done
fi

ipaddresses="`/bin/echo ${ipaddresses} | /usr/bin/tr ' ' '\n' | /usr/bin/sort -u`"

allow_list=" "
for ipaddress in ${ipaddresses}
do
  allow_list="${allow_list} --allow_list ${ipaddress}/32"
done

allow_list="${allow_list} --allow_list ${VPC_IP_RANGE}"


${HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_engine}/AdjustDBaaSFirewall.sh


/bin/echo "${ipaddresses}" > ${HOME}/runtime/dbaas_allowed_ips/ip_list.dat
