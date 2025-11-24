#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_relation_size.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2019/06/12 10:15:30 $
##
##      $Log: fuji_pg_check_postgres_relation_size.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_relation_size.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_postgres_common.sh

# Tutkitaan onko kanta standby roolissa jolloin ei ajeta tata
if chk_if_pg_is_in_recovery
then
  if [ "$1" = "show" ]
  then
    echo "$fuji_progname_base: PostgreSQL is in recovery. Exiting."
  fi
  exit 0
fi

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
for db in $DBS
do
$CHECK_POSTGRES_DIR/check_postgres_relation_size  --warning=$RELATION_SIZE_WARNING --critical=$RELATION_SIZE_CRITICAL --dbname=$db --perflimit=1 | \
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
done
rm -f $TMPFILE 1>/dev/null 2>&1
