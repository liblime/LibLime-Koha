#!/bin/bash

# Fill in with i-tiva server info and uncomment
# USER=
# PASSWD=
# HOSTNAME=

cd /tmp
HR=`eval date +%H`
DATE=`eval date +'%Y-%m-%d'`
if test $HR -lt 15 ; then
  /usr/bin/ncftpput -u $USER -p $PASSWD $HOSTNAME . TtMESSAGE.csv
  /bin/mv TtMESSAGE.csv TtMESSAGE-${DATE}.csv
  /usr/bin/touch TtMESSAGE.csv
  /bin/chmod 666 TtMESSAGE.csv
else
  /usr/bin/ncftpget -u $USER -p $PASSWD $HOSTNAME -DD . results.csv
  /bin/mv results.csv TtRESULTS-${DATE}.csv
  /bin/cp TtRESULTS-${DATE}.csv /tmp
fi

exit
