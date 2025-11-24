#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_database_size.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2019/06/12 10:15:30 $
##
##      $Log: fuji_pg_check_postgres_database_size.sh,v $
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
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_database_size.sh

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

$CHECK_POSTGRES_DIR/check_postgres_database_size  --warning=$DATABASE_SIZE_WARNING --critical=$DATABASE_SIZE_CRITICAL | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi

rm -f $TMPFILE 1>/dev/null 2>&1
