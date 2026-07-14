#!/bin/sh
##################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script will add an ip address (A Record) to the DNS provider
##################################################################################
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
####################################################################################
####################################################################################
#set -x

zoneid="${1}"
email="${2}"
credentials="${3}"
websiteurl="${4}"
ip="${5}"
dns="${6}"

if ( [ "${dns}" = "cloudflare" ] )
then
        if ( [ "`/bin/echo ${credentials} | /bin/grep ':::'`" != "" ] )
        then
                api_token="`/bin/echo ${credentials} | /usr/bin/awk -F':::' '{print $2}'`"
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" --data '{"type":"A","name":"'${websiteurl}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
        else
                authkey="${credentials}"
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${authkey}" -H "Content-Type: application/json" --data '{"type":"A","name":"'${websiteurl}'","content":"'${ip}'","proxiable":true,"proxied":'true',"ttl":120}'
        fi
fi

websiteurl="${4}"
domainurl="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
ip="${5}"
dns="${6}"


if ( [ "${dns}" = "digitalocean" ] )
then
        record_id="`/usr/local/bin/doctl compute domain records list ${domainurl} --config /root/.config/doctl/dns-do-config.yaml -o json | /usr/bin/jq -r '.[] | select (.data == "'${ip}'").id'`"
        if ( [ "${record_id}" != "" ] )
        then
                /usr/local/bin/doctl compute domain records delete  ${domainurl} ${record_id} --config /root/.config/doctl/dns-do-config.yaml
        fi
fi

authkey="${3}"
subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domainurl="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"

if ( [ "${dns}" = "exoscale" ] )
then
        domain_id="`/usr/bin/exo dns list --config /root/.config/exoscale/dns-exoscale.toml -O json | /usr/bin/jq -r '.[] | select (.name == "'${domainurl}'").id'`"

        if ( [ "${domain_id}" != "" ] )
        then
               record_id="`/usr/bin/exo dns show ${domain_id} --config /root/.config/exoscale/dns-exoscale.toml -O json | /usr/bin/jq -r '.[] | select (.content == "'${ip}'").id'`"
               if ( [ "${record_id}" != "" ] )
               then
                       /usr/bin/exo dns remove A ${domain_id} ${record_id} --config /root/.config/exoscale/dns-exoscale.toml
                fi
        fi
fi

subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domain_url="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"

if ( [ "${dns}" = "linode" ] )
then
        linode_config_file="/root/.config/dns-linode-cli"

        if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
        then
                linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
        fi

        export LINODE_CLI_CONFIG=${linode_config_file}

        domain_id="`/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id'`"
        record_id="`/usr/local/bin/linode-cli domains records-list ${domain_id} --no-defaults --json | /usr/bin/jq -r '.[] | select (.target == "'${ip}'").id'`"

        /usr/local/bin/linode-cli domains records-delete ${domain_id} ${record_id}

        unset LINODE_CLI_CONFIG

        if ( [ "${count}" = "5" ] )
        then
                ${HOME}/services/email/SendEmail.sh "FAILED TO ADD IP ADDRESS TO DNS SYSTEM" "IP address (${ip}) for domain ${domainurl}) could not be added to the DNS system" "ERROR"
        fi
fi

subdomain="`/bin/echo ${4} | /usr/bin/awk -F'.' '{print $1}'`"
domainurl="`/bin/echo ${4} | /usr/bin/cut -d'.' -f2-`"
ip="${5}"
dns="${6}"

if ( [ "${dns}" = "vultr" ] )
then
        record_id="`/usr/bin/vultr dns record list ${domainurl} --config /root/.dns-vultr-cli.yaml -o json | /usr/bin/jq -r '.records[] | select (.data == "'${ip}'").id'`"
        if ( [ "${record_id}" = "" ] )
        then
                /usr/bin/vultr dns record delete ${domainurl} ${record_id} --config /root/.dns-vultr-cli.yaml 
        fi
fi
