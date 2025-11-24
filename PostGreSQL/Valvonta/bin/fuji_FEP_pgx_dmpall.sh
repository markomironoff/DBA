#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2016 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_FEP_pgx_dmpall.sh,v $
##      $Revision: 1.2 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan FEP kannoista online-varmistukset
##
##      $Author: rosenjyr $
##      $Date: 2019/06/12 10:15:30 $
##
##      $Log: fuji_FEP_pgx_dmpall.sh,v $
##
# Revision 1.0  2016/02/18 14:42:05 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2018/08/09 13:54:03 fijyrrose ()
# Korjattu varmistushakemiston tutkiminen jos postgresql.conf tiedostoon
# on kommentoituna useampia backup_destination muuttujia.
#
# Revision 1.2  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_FEP_pgx_dmpall.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

DATE=$(date "+%Y%m%d")

touch $LOGFILE
fuji_subalku > $LOGFILE

# Poistetaan vanhat lokit 
LOGDIR=$(dirname $LOGFILE)
find $LOGDIR -name "*.log" -type f -mtime +${BACKUPLOGRETENTIONTIME} -exec rm -f {} \;

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_DUMP_BACKUP alert - can not get database information" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

# Tutkitaan onko kanta standby roolissa jolloin ei ajeta tata
if chk_if_pg_is_in_recovery
then
  echo "PostgreSQL is in recovery. Exiting." >> $LOGFILE
  fuji_subloppu >> $LOGFILE
  rm_old_flag_files
  exit 0
fi

BACKUP_DESTINATION=$(grep 'backup_destination' $PGDATA/postgresql.conf | grep -v "^#" | awk -F"=" '{print $2}' | tr -d ' '  | tr -d "\'")

if [  ! -w "$BACKUP_DESTINATION" ]                # Check Backup Directory exists.
then
    if chk_if_print_message "MAJOR"
    then
        echo "Backup Directory $BACKUP_DESTINATION does not exists" >> $LOGFILE
        echo "MAJOR PG_ONLINE_BACKUP alert - Backup Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    exit '-1'
fi

echo "*** pgx_dmpall -D $PGDATA ***" >> $LOGFILE
$PGHOME/bin/pgx_dmpall -D $PGDATA 1> /dev/null 2>> $LOGFILE
if [ $? != 0 ] 
then
    if chk_if_print_message "MAJOR"
    then
        cp $LOGFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - errors in pgx_dmpall" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        exit '-1'
    fi # end if chk_if...
else
    echo -e "\t*** pgx_dmpall: OK ***\n\t$($PGHOME/bin/pgx_rcvall -l -D $PGDATA)" >> $LOGFILE
fi

# echo Success! Total backup size: `du -sh "$BACKUP_DESTINATION"`
fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
