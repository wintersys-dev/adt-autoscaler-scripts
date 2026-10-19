

subject="$1"
message="$2"


EMAIL_PROVIDER="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPROVIDER'`"
FROM_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMFROMEMAILADDRESS'`"
FROM_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME | /usr/bin/sed 's/_//g''`"
TO_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMTOEMAILADDRESS'`"
USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILUSERNAME'`"
PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPASSWORD'`"

if ( [ "${EMAIL_PROVIDER}" = "1" ] )
then
	/usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s smtp-pulse.com:2525 -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"
fi

if ( [ "${EMAIL_PROVIDER}" = "2" ] )
then
	/usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s in.mailjet.com:2525 -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"            
fi
		
if ( [ "${EMAIL_PROVIDER}" = "3" ] )
then
	/usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s email-smtp.eu-west-1.amazonaws.com -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"
fi
	
