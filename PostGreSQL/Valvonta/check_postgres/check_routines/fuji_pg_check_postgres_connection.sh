#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_connection.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2015/11/03 16:40:13 $
##
##      $Log: fuji_pg_check_postgres_connection.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1   2015/11/03 16:40:13 fijyrrose ()
# Lisatty tarkistus josko instanssi onkin alhaalla
# -> ei tarvitse/kannata ajaa kaikkia tarkistuksia
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_connection.sh

rm -f /home/fujitsu/tmp/check_postgres_db_down
# Load common definitions
. /home/fujitsu/conf/fuji_check_postgres_common.sh

$CHECK_POSTGRES_DIR/check_postgres_connection --dbname=$CONNECTION_DBNAME | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi
grep "^CRITICAL" $WORKING_DIR/log/$fuji_progname_base.log 1>/dev/null 2>&1
if [ $? -eq 0 ]
then
  touch /home/fujitsu/tmp/check_postgres_db_down
fi
rm -f $TMPFILE 1>/dev/null 2>&1
