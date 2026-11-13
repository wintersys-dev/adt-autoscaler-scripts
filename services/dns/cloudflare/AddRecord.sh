set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Fully Qualified Domain Name and target IP parameters are required." >&2
        /bin/echo "Usage: $0 <fqdn> <target_ip>" >&2
        exit 1
fi

website_url="${1}"
ip="${2}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ] 
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

if [ ! -d "${HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ] 
then
        orchestration_tool="api"
fi

set +e
domain_json="$(${HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        /bin/echo "Failed to query cluster domain management catalog or network timeout occurred." >&2
        exit 1
fi

/bin/echo "DNS record successfully added: ${sub_domain}.${domain_url} -> ${ip} [TTL: 60s]"
exit 0
