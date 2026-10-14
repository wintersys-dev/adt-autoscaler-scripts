#!/bin/sh
########################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script checks if an instance with a particular name/type is running
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
########################################################################################
########################################################################################
#set -x

export HOME="`/bin/cat /home/homedir.dat`"
server_type="${1}"


if ( [ "`curl -s -H "Authorization: Bearer $TOKEN"  "https://api.linode.com/v4/linode/instances" |  jq -r '.data[] | select(.label | contains("'${server_type}'")).status'`" = "running" ] )
then
        /bin/echo "running"
else
        /bin/echo "not running"
fi
