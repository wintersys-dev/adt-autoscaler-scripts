


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: 3 arguments are required."
        status "Usage: $0 <subject> <message> <to_address>"
        exit 1
fi

subject="$1"
message="$2"
to_address="$3"


EMAIL_PROVIDER="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPROVIDER'`"
FROM_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMFROMEMAILADDRESS'`"
FROM_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME | /usr/bin/sed 's/_//g''`"
TO_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMTOEMAILADDRESS'`"
USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILUSERNAME'`"
PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPASSWORD'`"


if ( [ "${to_address}" != "" ] )
then
	TO_ADDRESS="${to_address}"
fi

if ( [ ! -f ${HOME}/runtime/SSMTP_INITIALISED ] )
then
	if ( [ "${EMAIL_PROVIDER}" = "1" ] )
	then
		/bin/echo "mailhub=smtp-pulse.com:2525" >> /etc/ssmtp/ssmtp.conf
	fi
	if ( [ "${EMAIL_PROVIDER}" = "2" ] )
	then
		/bin/echo "mailhub=in-v3.mailjet.com:587" >> /etc/ssmtp/ssmtp.conf
	fi
	if ( [ "${EMAIL_PROVIDER}" = "3" ] )
	then
		/bin/echo "mailhub=email-smtp.eu-west-1.amazonaws.com" >> /etc/ssmtp/ssmtp.conf
	fi

	/bin/echo "AuthUser=${USERNAME}" >> /etc/ssmtp/ssmtp.conf
	/bin/echo "AuthPass=${PASSWORD}" >> /etc/ssmtp/ssmtp.conf
	/bin/echo "FromLineOverride=YES" >> /etc/ssmtp/ssmtp.conf
	/bin/echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf
	/bin/touch ${HOME}/runtime/SSMTP_INITIALISED
fi

if ( [ "${content_type}" = "HTML" ] )
then
	/bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}" -a 'Content-Type: text/html'
else
	/bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}"
fi

