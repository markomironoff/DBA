#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2021
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_chk_lock_queue.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Tarkistetaan onko klusteri ja kannat saatavilla
##
##      $Author: rosenjyr $
##      $Date: 2020/01/15 14:10:03 $
##
##      $Log: fuji_pg_chk_lock_queue.sh,v $
##
# Revision 1.0  2020/01/15 14:10:03  fijyrrose ()
# Eka versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_chk_lock_queue.sh

# Debug
# export VFY_ALL=1

#  Load common routines
. /home/fujitsu/conf/fuji_pg_common.sh

# echo "logfile: $LOGFILE"
touch $LOGFILE
fuji_subalku > $LOGFILE

$PSQL fuji_dba_db -c "select now()" 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    if chk_if_print_message "WARNING"
    then
        cp $TMPFILE $WORKING_DIR/tmp/postgres_main_errors.out
        echo "MAJOR PG_LOCKING_QUEUE alert - database fuji_dba_db not available" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        /bin/rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi


my_tmp=$($PSQL fuji_dba_db -t -f /home/fujitsu/dba/sql/locking_queue.sql | awk -F'|' '{ printf $1 }')
# echo $my_tmp
if [ -z "$my_tmp" ]; then
  echo "$my_tmp oli tyhja"
  /bin/rm -rf /home/fujitsu/tmp/fuji_pg_chk_lock_queue.sh.queue
  /bin/rm -rf /home/fujitsu/tmp/fuji_pg_chk_lock_queue.sh.queue.ed
else
  if [ -f /home/fujitsu/tmp/$fuji_progname_base.queue ]; then
     cp /home/fujitsu/tmp/$fuji_progname_base.queue /home/fujitsu/tmp/$fuji_progname_base.queue.ed
  else
     echo "1" > /home/fujitsu/tmp/$fuji_progname_base.queue.ed
  fi
  $PSQL fuji_dba_db -q -f /home/fujitsu/dba/sql/locking_tree.sql > /home/fujitsu/tmp/$fuji_progname_base.queue 2>/dev/null
  diff -q /home/fujitsu/tmp/$fuji_progname_base.queue /home/fujitsu/tmp/$fuji_progname_base.queue.ed 1>/dev/null 2>&1
  if [ $? -ne 0 ]
  then
         cp /home/fujitsu/tmp/$fuji_progname_base.queue $WORKING_DIR/tmp/postgres_main_errors.out
         echo "MAJOR PG_LOCKING_QUEUE alert - transactions waiting locks" | \
         ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
         cat /home/fujitsu/tmp/$fuji_progname_base.queue >> /home/fujitsu/log/alarm_messages.out
         /bin/rm -rf $TMPFILE
         exit '-1'
  else
     # Oli edelleen lukkojoja, mutta siita on jo raportoitu
     if chk_if_print_message "MAJOR"
     then
        cp /home/fujitsu/tmp/$fuji_progname_base.queue $WORKING_DIR/tmp/postgres_main_errors.out
        echo "MAJOR PG_STATUS_CHK - PG_LOCKING_QUEUE alert - transactions waiting locks" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        cat /home/fujitsu/tmp/$fuji_progname_base.queue >> /home/fujitsu/log/alarm_messages.out
        /bin/rm -rf $TMPFILE
      fi # end if chk_if..
      exit 0
  fi # end if [ $? -ne 0 ]
fi # end if [ -z "$my_tmp" ]

fuji_subloppu >> $LOGFILE
/bin/rm -rf $LOGFILE
/bin/rm -rf $TMPFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files
exit 0
