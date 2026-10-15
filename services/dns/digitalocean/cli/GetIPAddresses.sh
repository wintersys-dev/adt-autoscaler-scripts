#!/bin/sh
##########################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will get all the IP addresses active for a given subdomain
# with the DNS provider we are using
###########################################################################################
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
##########################################################################################
##########################################################################################
#set -x


websiteurl="${2}"
domainurl="`/bin/echo ${2} | /usr/bin/cut -d'.' -f2-`"
subdomain="`/bin/echo ${2} | /usr/bin/awk -F'.' '{print $1}'`"
dns="${5}"


	/usr/local/bin/doctl compute domain records list ${domainurl} --config /root/.config/doctl/dns-do-config.yaml -o json | /usr/bin/jq -r '.[] | select (.type == "A") | select (.name == "'${subdomain}'").data'


#!/bin/sh
##########################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will get all the IP addresses active for a given subdomain
# with the DNS provider we are using
###########################################################################################
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
##########################################################################################
##########################################################################################
#set -x

websiteurl="${2}"
domainurl="`/bin/echo ${2} | /usr/bin/cut -d'.' -f2-`"
subdomain="`/bin/echo ${2} | /usr/bin/awk -F'.' '{print $1}'`"
dns="${5}"


	/usr/local/bin/doctl compute domain records list ${domainurl} --config /root/.config/doctl/dns-do-config.yaml -o json | /usr/bin/jq -r '.[] | select (.type == "A") | select (.name == "'${subdomain}'").data'
