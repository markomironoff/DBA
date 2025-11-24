#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_wal_files.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_wal_files.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_wal_files.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_postgres_common.sh

$CHECK_POSTGRES_DIR/check_postgres_wal_files  --warning=$WAL_FILES_WARNING --critical=$WAL_FILES_CRITICAL | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi

rm -f $TMPFILE 1>/dev/null 2>&1
