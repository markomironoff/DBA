#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2021
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_rm_pglogs.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL pg_log hakemistoon lokien pakkaus/tyhjays
##
##      $Author: rosenjyr $
##      $Date: 2021/03/12 13:15:30 $
##
##      $Log: fuji_pg_rm_pglogs.sh,v $
##
# Revision 1.0  2021/03/12 13:15:30 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_rm_pglogs.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

DATE=$(date "+%Y%m%d")

PG_LOGDIR=$PGDATA/pg_log

touch $LOGFILE
fuji_subalku > $LOGFILE

if [ $# -lt 2 ]
then
    if chk_if_print_message "WARNING"
    then
        echo "Aja komento:  fuji_pg_rm_pglogs.sh keep_newer_than compress_older_than" >> $LOGFILE
        echo "WARNING PG_LOG_MAINTENANCE alert - Illegal number of parameters" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
#        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

LAST_MODIFIED="$1"      # esim. 90 -> sailytetaan 3kk
COMPRESS_AFTER="$2"     # esim. 7 -> pakataan viikkoa vanhemmat

if [ ! -e "$PG_LOGDIR" ]
then
    if chk_if_print_message "WARNING"
    then
        echo "PG_LOG hakemisto puuttuu:  $PG_LOGDIR" >> $LOGFILE
        echo "WARNING PG_LOG_MAINTENANCE alert - PG_LOG hakemisto puuttuu:  $PG_LOGDIR" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    exit '-1'
fi

COMPRESS_CMD=$(which bzip2 2>/dev/null)
if [ ! -x "$COMPRESS_CMD" ]; then
  COMPRESS_CMD=$(which gzip 2>/dev/null)
  if [ ! -x "$COMPRESS_CMD" ]; then
    if chk_if_print_message "WARNING"
    then
        echo "Pakkausohjelma puuttuu: bzip2/gzip" >> $LOGFILE
        echo "WARNING PG_LOG_MAINTENANCE alert - Pakkausohjelma puuttuu: bzip2/gzip" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    exit '-1'
  fi
fi

FIND_CMD=$(which find 2>/dev/null)
if [ ! -x "$FIND_CMD" ]; then
  if chk_if_print_message "WARNING"
  then
      echo "Pakkausohjelma puuttuu: bzip2/gzip" >> $LOGFILE
      echo "WARNING PG_LOG_MAINTENANCE alert - Apuohjelma puuttuu: find" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
  exit '-1'
fi

RM_CMD=$(which rm 2>/dev/null)
if [ ! -x "$RM_CMD" ]; then
  if chk_if_print_message "WARNING"
  then
      echo "Poisto-ohjelma puuttuu: rm" >> $LOGFILE
      echo "WARNING PG_LOG_MAINTENANCE alert - Poisto-ohjelma puuttuu: rm" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
  exit '-1'
fi

XARGS_CMD=$(which xargs 2>/dev/null)
if [ ! -x "$XARGS_CMD" ]; then
  if chk_if_print_message "WARNING"
  then
      echo "Apuohjelma puuttuu: xargs" >> $LOGFILE
      echo "WARNING PG_LOG_MAINTENANCE alert - Apuohjelma puuttuu: xargs" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
  exit '-1'
fi

NICE_CMD=$(which nice 2>/dev/null)
if [ ! -x "$NICE_CMD" ]; then
  if chk_if_print_message "WARNING"
  then
      echo "Apuohjelma puuttuu: nice" >> $LOGFILE
      echo "WARNING PG_LOG_MAINTENANCE alert - Apuohjelma puuttuu: nice" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
  exit '-1'
fi

RM_CMD=$(echo $RM_CMD -f)
# echo $RM_CMD
# RM_CMD=$(echo ls -l)
# Poistetaan vanhemmat kuin (LAST_MODIFIED)
echo "Poistetaan:" >>$LOGFILE
$FIND_CMD $PG_LOGDIR -type f -mtime +${LAST_MODIFIED} -exec ls -l {} \; >>$LOGFILE
$FIND_CMD $PG_LOGDIR -type f -mtime +${LAST_MODIFIED} -exec $RM_CMD {} \;

# Pakataan vanhemmat kuin (COMPRESS_AFTER)
echo "Pakataan:" >>$LOGFILE
$FIND_CMD $PG_LOGDIR -not  -name "*.bz2" -not -name "*.gz" -type f -mtime +${COMPRESS_AFTER} -exec ls -l {} \; >>$LOGFILE
$FIND_CMD $PG_LOGDIR -not  -name "*.bz2" -not -name "*.gz" -type f -mtime +${COMPRESS_AFTER} -exec $NICE_CMD -n 19 $COMPRESS_CMD -9 {} \;

fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0

