#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2018
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_integrity_check.sh,v $
##      $Revision: 1.x $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL kannoista eheystarkistukset block korruptien loytamiseksi
##
##      $Author: rosenjyr $
##      $Date: 2018/04/30 14:44:41 $
##
##      $Log: fuji_pg_integrity_check.sh,v $
##
# Revision 1.0  2018/04/30 14:44:41 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_integrity_check.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

if [ $# -lt 1 ]
then
  TIMEOUT=14400
else
  TIMEOUT=$1
fi
my_timeout=$TIMEOUT
DATE=$(date "+%Y%m%d")

touch $LOGFILE
fuji_subalku > $LOGFILE

fuji_get_seconds
start_time=$fuji_value

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
ret_code=$?
if [ $ret_code -ne 0 ] 
then
    echo "WARNING PG_INTEGRITY_CHECK  error - can not get database information " >>$LOGFILE
    cat $TMPFILE >>$LOGFILE
    if chk_if_print_message "WARNING"
    then
        echo "WARNING PG_INTEGRITY_CHECK  error - can not get database information" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit $ret_code
fi

DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
/bin/rm -rf $TMPFILE

echo "*** pg_dumpall --globals-only ***" >> $LOGFILE
$DUMPALL $PG_CONNECT_OPTS --globals-only -f /dev/null 1>/dev/null 2>>$LOGFILE
ret_code=$?
if [ $ret_code -ne 0 ]
then
    echo "WARNING PG_INTEGRITY_CHECK  error - errors in pg_dumpall " >>$LOGFILE
    cat $TMPFILE >>$LOGFILE
    if chk_if_print_message "WARNING"
    then
        echo "WARNING PG_INTEGRITY_CHECK  error - errors in pg_dumpall" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit $ret_code
fi

DUMP_OPTS=" --create --format plain --blobs --lock-wait-timeout=30000 "
for database in $DBS; do
    BACKUPFILE="/dev/null"
# Timeout check
    fuji_get_seconds
    curr_time=$fuji_value
    fuji_duration $start_time $curr_time
    duration_time=$fuji_value
    my_timeout=$((my_timeout - duration_time))
    if [ $my_timeout -lt 1 ]
    then
      echo "WARNING PG_INTEGRITY_CHECK  error - timeout - $TIMEOUT " >>$LOGFILE
      if chk_if_print_message "WARNING"
      then
        echo "WARNING PG_INTEGRITY_CHECK  error - timeout - $TIMEOUT" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      fi # end if chk_if...
      exit 1
    fi

    echo "***   Test table integrity -  database: $database `date`***" >> $LOGFILE
    timeout $my_timeout $PGDUMP $PG_CONNECT_OPTS $DUMP_OPTS --file "$BACKUPFILE" $database  1>/dev/null 2>>$LOGFILE
    ret_code=$?
    if [ $ret_code -ne 0 ]
    then
      echo "WARNING PG_INTEGRITY_CHECK  error - errors in pg_dump with database $database - $ret_code " >>$LOGFILE
      if chk_if_print_message "WARNING"
      then
         echo "WARNING PG_INTEGRITY_CHECK  error - errors in pg_dump with database $database - $ret_code" | \
         ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      fi # end if chk_if...
      exit $ret_code
    else
        echo -e "\t*** Table data in database: \t$database \tOK  - `date`  ***" >> $LOGFILE
    fi
done

for database in $DBS; do
# Timeout check
    fuji_get_seconds
    curr_time=$fuji_value
    fuji_duration $start_time $curr_time
    duration_time=$fuji_value
    my_timeout=$((my_timeout - duration_time))
    if [ $my_timeout -lt 1 ]
    then
      echo "WARNING PG_INTEGRITY_CHECK  error - timeout - $TIMEOUT " >>$LOGFILE
      if chk_if_print_message "WARNING"
      then
        echo "WARNING PG_INTEGRITY_CHECK  error - timeout - $TIMEOUT" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
      fi # end if chk_if...
      exit 1
    fi

    echo "***   Test index integrity -  database: $database `date`***" >> $LOGFILE
    $PSQL -v "ON_ERROR_STOP=1" -f /home/fujitsu/dba/cre_row_count_func.sql $database 1>/dev/null 2>>$LOGFILE
    ret_code=$?
    if [ $ret_code -ne 0 ]
    then
      echo "WARNING PG_INTEGRITY_CHECK  error - can not create function for index check - database $database - $ret_code" >>$LOGFILE
      if chk_if_print_message "WARNING"
      then
         echo "WARNING PG_INTEGRITY_CHECK  error - can not create function for index check - database $database" | \
         ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      fi # end if chk_if...
      exit $ret_code
    fi
    timeout $my_timeout $PSQL -v "ON_ERROR_STOP=1" -f /home/fujitsu/dba/check_index_integrity.sql $database 1>/dev/null 2>>$LOGFILE
    ret_code=$?
    if [ $ret_code -ne 0 ]
    then
      echo "WARNING PG_INTEGRITY_CHECK  error - index integrity check - database $database - $ret_code" >>$LOGFILE
      if chk_if_print_message "WARNING"
      then
         echo "WARNING PG_INTEGRITY_CHECK  error - index integrity check - database $database" | \
         ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      fi # end if chk_if...
      exit $ret_code
    else
        echo -e "\t*** Primary key/unique Indexes in database: \t$database \tOK  - `date`  ***" >> $LOGFILE
    fi

done
fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
