#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2016 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_maintenance.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Kannan huoltorutiineita.
##
##      Lisaa tahan halutut rutiinit. 
##      Muista hoitaa virhetarkistus ja lokitus ongelmatilanteessa
##
##      $Author: rosenjyr $
##      $Date: 2019/06/12 10:15:30 $
##
##      $Log: fuji_pg_maintenance.sh,v $
##
# Revision 1.0  2016/02/01 10:14:05  fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_maintenance.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh


touch $LOGFILE
fuji_subalku > $LOGFILE

# Tarkistetaan etta instanssi on paalla
$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ] 
then
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_maintenance_errors.out
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

# Esim. ajetaan vacuum kaikille muille kannoille paitsi template0
DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
/bin/rm -rf $TMPFILE
# Tai voit luetetta kannat joille ajetaan, esim.
# DBS="backup_test fuji_dba_db jokudb1"


for database in $DBS; do
    echo "***   VACUUM database: $database ***" >> $LOGFILE
    $PGHOME/bin/vacuumdb -d $database -z -v  1>/dev/null 2>>$LOGFILE
    if [ $? != 0 ] 
    then
        if chk_if_print_message "MAJOR"
        then
            cp $LOGFILE $WORKING_DIR/tmp/pg_maintenance_errors.out
            echo "MAJOR PG_DUMP_BACKUP alert - errors in vacuum with database $database" | \
            ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
            exit '-1'
        fi # end if chk_if...
    else
        echo -e "\t***   VACUUM database: \t$database \tOK ***" >> $LOGFILE
    fi
done

# echo Success!"`
fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
