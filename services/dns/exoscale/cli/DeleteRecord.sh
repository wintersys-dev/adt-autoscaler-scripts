#!/bin/sh
#######################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will delete a DNS A record using the 'record id' to delete it
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
#####################################################################################
#####################################################################################
#set -x

HOME="`/bin/cat /home/homedir.dat`"

recordid="${2}"
authkey="${4}"
dns="${5}"
domainurl="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL' | /usr/bin/cut -d'.' -f2-`"


        /usr/bin/exo dns remove ${domainurl} ${recordid} -Q -f --config /root/.config/exoscale/dns-exoscale.toml
        #Alternative
        # /usr/bin/curl  -H "X-DNS-Token: ${authkey}"  -H 'Accept: application/json' -X DELETE  https://api.exoscale.com/dns/v1/domains/${domainurl}/records/${recordid}

