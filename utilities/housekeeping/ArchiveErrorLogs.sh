

archive_date="archive-`/usr/bin/date +%d.%m.%y`"

/bin/tar -cvfz ${HOME}/logs/archives/${archive_date}/archive.tar.gz --exclude "${HOME}/logs/archives" ${HOME}/logs
