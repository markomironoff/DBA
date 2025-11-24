#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_query_time.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_query_time.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_query_time.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_postgres_common.sh

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
for db in $DBS
do
$CHECK_POSTGRES_DIR/check_postgres_query_time  --excludeuser=postgres --warning="$QUERY_TIME_WARNING" --critical="$QUERY_TIME_CRITICAL" --dbname=$db --perflimit=1 | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi
grep "^CRITICAL" $WORKING_DIR/log/$fuji_progname_base.log 1>/dev/null 2>&1
if [ $? = 0 ]
then
 break
fi
# break ensimmaisen jalkeen kun nayttaa koko instanssin kyselyt heti
break
done
rm -f $TMPFILE 1>/dev/null 2>&1
