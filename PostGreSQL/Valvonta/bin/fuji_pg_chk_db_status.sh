#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_chk_db_status.sh,v $
##      $Revision: 1.3 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Tarkistetaan onko klusteri ja kannat saatavilla
##
##      $Author: rosenjyr $
##      $Date: 2011/12/20 14:10:03 $
##
##      $Log: fuji_pg_chk_db_status.sh,v $
##
# Revision 1.1  2015/10/18  14:19:04  fijyrrose ()
# Lisatty kantakohtaisen tarkistuksen tulostus "putkelle"

##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_chk_db_status.sh

# Debug
# export VFY_ALL=1

#  Load common routines
. /home/fujitsu/conf/fuji_pg_common.sh

# echo "logfile: $LOGFILE"
touch $LOGFILE
fuji_subalku > $LOGFILE

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ] 
then
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/postgres_main_errors.out
        echo "MAJOR PG_STATUS_CHK alert - database main information not available" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        /bin/rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
/bin/rm -rf $TMPFILE

for database in $DBS; do
    $PSQL $PG_CONNECT_OPTS -l $database 1>$TMPFILE 2>&1
    if [ $? != 0 ] 
    then
        if chk_if_print_message "MAJOR"
        then
            cp $TMPFILE $WORKING_DIR/tmp/postgres_main_errors.out
            echo "MAJOR PG_STATUS_CHK alert - database information not available, database $database" | \
            ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
            exit '-1'
	    /bin/rm -rf $TMPFILE
        fi # end if chk_if...
    fi
    echo "***   Database: $database available***" | tee -a  $LOGFILE
done

fuji_subloppu >> $LOGFILE
/bin/rm -rf $LOGFILE
/bin/rm -rf $TMPFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files
exit 0
