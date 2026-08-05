#set -x

current_day="`/usr/bin/date +%d`"
current_month="`/usr/bin/date +%m | /bin/sed 's/^0//g'`"
current_year="`/usr/bin/date +%y`"
archive_day="`/usr/bin/expr ${current_day} - 1`"
archive_date="archive-${archive_day}-${current_month}-${current_year}"

if ( [ ! -d ${HOME}/logs/archives/${archive_date} ] )
then
        /bin/mkdir -p ${HOME}/logs/archives/${archive_date}
fi

cd ${HOME}/logs
/bin/tar cvfz ${HOME}/logs/archives/${archive_date}/archive.tar.gz --exclude "./archives" .
