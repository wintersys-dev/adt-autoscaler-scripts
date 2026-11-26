#!/bin/sh
#: Name:        InitialiseCloudhostConfig.sh
#: Purpose:     Generates primary and DNS-scoped CLI configuration files for DigitalOcean, Exoscale, Linode, and Vultr.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseCloudhostConfig.sh
#:              InitialiseCloudhostConfig.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads CLOUDHOST, DNSSECURITYKEY, and provider-specific credentials from configuration.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#:   - ${HOME}/services/cloudhost/configfiles/<provider>/*
#:   - External binaries: cat, echo, printf, grep, cut, awk, sed, mkdir, cp, chown, chmod, touch, sleep
#:
#: Exit Codes:
#:   0          Cloudhost CLI configuration files generated and secured cleanly
#:   1          Missing /home/homedir.dat, missing required credentials/templates, or file write failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the server toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
        export HOME
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"
style_extractor="${HOME}/utilities/config/ExtractBuildStyleValues.sh"

if [ ! -x "${config_extractor}" ]
then
        /bin/echo "Error: ExtractConfigValue.sh missing or not executable at ${config_extractor}" >&2
        exit 1
fi

# Escape sed replacement special characters (&, \, and delimiter |)
escape_sed_rep()
{
        printf '%s' "${1}" | /bin/sed -e 's/[\\&|]/\\&/g'
}

set +e
CLOUDHOST="$("${config_extractor}" 'CLOUDHOST')"
DNS_SECURITY_KEY="$("${config_extractor}" 'DNSSECURITYKEY')"
set -e

if [ -z "${CLOUDHOST}" ]
then
        /bin/echo "Error: CLOUDHOST configuration value is missing." >&2
        exit 1
fi

umask 077

# 1. DigitalOcean (doctl)
if [ "${CLOUDHOST}" = "digitalocean" ]
then
        set +e
        TOKEN="$("${config_extractor}" 'TOKEN')"
        set -e

        if [ -z "${TOKEN}" ]
        then
                /bin/echo "${0}: Couldn't find your DigitalOcean account personal access token; exiting." >&2
                exit 1
        fi

        tmpl_file="${HOME}/services/cloudhost/configfiles/digitalocean/digitalocean.tmpl"
        if [ ! -r "${tmpl_file}" ]
        then
                /bin/echo "Error: DigitalOcean CLI template missing at ${tmpl_file}" >&2
                exit 1
        fi

        /bin/echo "${0}: Configuring DigitalOcean CLI tool"
        /bin/mkdir -p "${HOME}/.config/doctl" /root/.config/doctl

        /bin/cp "${tmpl_file}" "${HOME}/.config/doctl/config.yaml"
        escaped_token="$(escape_sed_rep "${TOKEN}")"
        /bin/sed -i "s|XXXXTOKENXXXX|${escaped_token}|g" "${HOME}/.config/doctl/config.yaml"

        /bin/cp "${HOME}/.config/doctl/config.yaml" /root/.config/doctl/config.yaml
        /bin/chown root:root "${HOME}/.config/doctl/config.yaml" /root/.config/doctl/config.yaml
        /bin/chmod 400 "${HOME}/.config/doctl/config.yaml" /root/.config/doctl/config.yaml

        if [ -n "${DNS_SECURITY_KEY}" ]
        then
                /bin/cp "${HOME}/.config/doctl/config.yaml" /root/.config/doctl/dns-do-config.yaml
                escaped_dns_key="$(escape_sed_rep "${DNS_SECURITY_KEY}")"
                /bin/sed -i "s|^access-token.*|access-token: ${escaped_dns_key}|" /root/.config/doctl/dns-do-config.yaml
                /bin/chown root:root /root/.config/doctl/dns-do-config.yaml
                /bin/chmod 400 /root/.config/doctl/dns-do-config.yaml
        fi
fi

# 2. Exoscale (exo)
if [ "${CLOUDHOST}" = "exoscale" ]
then
        set +e
        CLOUDHOST_ACCOUNT_ID="$("${config_extractor}" 'CLOUDHOSTACCOUNTID')"
        REGION="$("${config_extractor}" 'REGION')"
        ACCESS_KEY="$("${config_extractor}" 'ACCESSKEY')"
        SECRET_KEY="$("${config_extractor}" 'SECRETKEY')"
        set -e

        if [ -z "${CLOUDHOST_ACCOUNT_ID}" ] || [ -z "${REGION}" ] || [ -z "${ACCESS_KEY}" ] || [ -z "${SECRET_KEY}" ]
        then
                /bin/echo "${0}: Missing required Exoscale credentials (CLOUDHOSTACCOUNTID, REGION, ACCESSKEY, or SECRETKEY); exiting." >&2
                exit 1
        fi

        tmpl_file="${HOME}/services/cloudhost/configfiles/exoscale/exoscale.tmpl"
        if [ ! -r "${tmpl_file}" ]
        then
                /bin/echo "Error: Exoscale CLI template missing at ${tmpl_file}" >&2
                exit 1
        fi

        /bin/echo "${0}: Configuring Exoscale CLI tool"
        /bin/mkdir -p "${HOME}/.config/exoscale" /root/.config/exoscale

        /bin/cp "${tmpl_file}" "${HOME}/.config/exoscale/exoscale.toml"

        escaped_email="$(escape_sed_rep "${CLOUDHOST_ACCOUNT_ID}")"
        escaped_region="$(escape_sed_rep "${REGION}")"
        escaped_access="$(escape_sed_rep "${ACCESS_KEY}")"
        escaped_secret="$(escape_sed_rep "${SECRET_KEY}")"

        /bin/sed -i "s|XXXXCLOUDEMAILADDRESSXXXX|${escaped_email}|g" "${HOME}/.config/exoscale/exoscale.toml"
        /bin/sed -i "s|XXXXREGIONXXXX|${escaped_region}|g" "${HOME}/.config/exoscale/exoscale.toml"
        /bin/sed -i "s|XXXXACCESSKEYXXXX|${escaped_access}|g" "${HOME}/.config/exoscale/exoscale.toml"
        /bin/sed -i "s|XXXXSECRETKEYXXXX|${escaped_secret}|g" "${HOME}/.config/exoscale/exoscale.toml"

        /bin/cp "${HOME}/.config/exoscale/exoscale.toml" /root/.config/exoscale/exoscale.toml
        /bin/chown root:root "${HOME}/.config/exoscale/exoscale.toml" /root/.config/exoscale/exoscale.toml
        /bin/chmod 400 "${HOME}/.config/exoscale/exoscale.toml" /root/.config/exoscale/exoscale.toml

        if [ -n "${DNS_SECURITY_KEY}" ]
        then
                /bin/cp "${HOME}/.config/exoscale/exoscale.toml" /root/.config/exoscale/dns-exoscale.toml
                DNS_ACCESS_KEY="${DNS_SECURITY_KEY%%:*}"
                DNS_SECRET_KEY="${DNS_SECURITY_KEY#*:}"
                escaped_dns_access="$(escape_sed_rep "${DNS_ACCESS_KEY}")"
                escaped_dns_secret="$(escape_sed_rep "${DNS_SECRET_KEY}")"

                /bin/sed -i "s|^key.*|key = \"${escaped_dns_access}\"|" /root/.config/exoscale/dns-exoscale.toml
                /bin/sed -i "s|^secret.*|secret = \"${escaped_dns_secret}\"|" /root/.config/exoscale/dns-exoscale.toml
                /bin/chown root:root /root/.config/exoscale/dns-exoscale.toml
                /bin/chmod 400 /root/.config/exoscale/dns-exoscale.toml
        fi
fi
# 3. Linode (linode-cli)
orch_tool=""
if [ -x "${style_extractor}" ]
then
        set +e
        orch_tool="$("${style_extractor}" "ORCHESTRATION_TOOL" 2>/dev/null | /usr/bin/awk -F':' '{print $NF}')"
        set -e
fi

if [ "${CLOUDHOST}" = "linode" ] && [ "${orch_tool}" = "cli" ]
then
        set +e
        CLOUDHOST_ACCOUNT_ID="$("${config_extractor}" 'CLOUDHOSTACCOUNTID')"
        TOKEN="$("${config_extractor}" 'TOKEN')"
        REGION="$("${config_extractor}" 'REGION')"
        set -e

        if [ -z "${CLOUDHOST_ACCOUNT_ID}" ] || [ -z "${TOKEN}" ] || [ -z "${REGION}" ]
        then
                /bin/echo "${0}: Missing required Linode credentials (CLOUDHOSTACCOUNTID, TOKEN, or REGION); exiting." >&2
                exit 1
        fi

        tmpl_file="${HOME}/services/cloudhost/configfiles/linode/linode-cli.tmpl"
        if [ ! -r "${tmpl_file}" ]
        then
                /bin/echo "Error: Linode CLI template missing at ${tmpl_file}" >&2
                exit 1
        fi

        log_dir="${HOME}/logs/initialbuild"
        /bin/mkdir -p "${log_dir}" "${HOME}/.config" /root/.config
        /bin/echo "${0}: Configuring Linode CLI tool" >> "${log_dir}/BUILD_PROCESS_MONITORING.log"

        /bin/cp "${tmpl_file}" "${HOME}/.config/linode-cli"

        escaped_account="$(escape_sed_rep "${CLOUDHOST_ACCOUNT_ID}")"
        escaped_token="$(escape_sed_rep "${TOKEN}")"
        escaped_region="$(escape_sed_rep "${REGION}")"

        /bin/sed -i "s|XXXXLINODEACCOUNTUSERNAMEXXXX|${escaped_account}|g" "${HOME}/.config/linode-cli"
        /bin/sed -i "s|XXXXTOKENXXXX|${escaped_token}|g" "${HOME}/.config/linode-cli"
        /bin/sed -i "s|XXXXREGIONXXXX|${escaped_region}|g" "${HOME}/.config/linode-cli"

        /bin/cp "${HOME}/.config/linode-cli" /root/.config/linode-cli
        /bin/chown root:root /root/.config/linode-cli "${HOME}/.config/linode-cli"
        /bin/chmod 400 /root/.config/linode-cli "${HOME}/.config/linode-cli"

        if [ -n "${DNS_SECURITY_KEY}" ]
        then
                /bin/cp "${HOME}/.config/linode-cli" /root/.config/dns-linode-cli
                /bin/cp "${HOME}/.config/linode-cli" "${HOME}/.config/dns-linode-cli"
                escaped_dns_key="$(escape_sed_rep "${DNS_SECURITY_KEY}")"
                /bin/sed -i "s|^token.*|token = ${escaped_dns_key}|" "${HOME}/.config/dns-linode-cli"
                /bin/sed -i "s|^token.*|token = ${escaped_dns_key}|" /root/.config/dns-linode-cli
                /bin/chown root:root /root/.config/dns-linode-cli "${HOME}/.config/dns-linode-cli"
                /bin/chmod 400 /root/.config/dns-linode-cli "${HOME}/.config/dns-linode-cli"
        fi

        if [ -f "${HOME}/runtime/software.dat" ] && /bin/grep -q '^CLOUDCLITOOL:linode-cli:snap' "${HOME}/runtime/software.dat"
        then
                /snap/bin/linode-cli >/dev/null 2>&1 &
                count=0
                while [ "${count}" -lt 5 ]
                do
                        if [ -d /root/snap/linode-cli/current/.config ]
                        then
                                /bin/cp "${HOME}/.config/linode-cli" /root/snap/linode-cli/current/.config/linode-cli
                                /bin/chmod 400 /root/snap/linode-cli/current/.config/linode-cli
                                if [ -f "${HOME}/.config/dns-linode-cli" ]
                                then
                                        /bin/cp "${HOME}/.config/dns-linode-cli" /root/snap/linode-cli/current/.config/dns-linode-cli
                                        /bin/chmod 400 /root/snap/linode-cli/current/.config/dns-linode-cli
                                fi
                                break
                        fi
                        count=$((count + 1))
                        /bin/sleep 5
                done
        fi
fi

# 4. Vultr (vultr-cli)
if [ "${CLOUDHOST}" = "vultr" ]
then
        set +e
        TOKEN="$("${config_extractor}" 'TOKEN')"
        set -e

        if [ -z "${TOKEN}" ]
        then
                /bin/echo "${0}: Couldn't find your Vultr API key; exiting." >&2
                exit 1
        fi

        /bin/mkdir -p "${HOME}/.config" /root/.config

        /usr/bin/touch "${HOME}/.config/VULTRAPIKEY:${TOKEN}"
        /bin/chmod 400 "${HOME}/.config/VULTRAPIKEY:${TOKEN}"
        printf 'api-key: %s\n' "${TOKEN}" > "${HOME}/.vultr-cli.yaml"
        printf 'api-key: %s\n' "${TOKEN}" > /root/.vultr-cli.yaml
        /bin/chown root:root "${HOME}/.vultr-cli.yaml" /root/.vultr-cli.yaml
        /bin/chmod 400 "${HOME}/.vultr-cli.yaml" /root/.vultr-cli.yaml

        if [ -n "${DNS_SECURITY_KEY}" ]
        then
                /usr/bin/touch "${HOME}/.config/VULTRDNSAPIKEY:${DNS_SECURITY_KEY}"
                /bin/chmod 400 "${HOME}/.config/VULTRDNSAPIKEY:${DNS_SECURITY_KEY}"
                printf 'api-key: %s\n' "${DNS_SECURITY_KEY}" > "${HOME}/.dns-vultr-cli.yaml"
                printf 'api-key: %s\n' "${DNS_SECURITY_KEY}" > /root/.dns-vultr-cli.yaml
                /bin/chown root:root "${HOME}/.dns-vultr-cli.yaml" /root/.dns-vultr-cli.yaml
                /bin/chmod 400 "${HOME}/.dns-vultr-cli.yaml" /root/.dns-vultr-cli.yaml
        fi
fi

exit 0

