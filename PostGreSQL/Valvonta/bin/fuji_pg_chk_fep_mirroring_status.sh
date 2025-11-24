#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_chk_fep_mirroring_status.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Tarkistetaan Mirroring Controllerin status
##
##      $Author: rosenjyr $
##      $Date: 2019/06/06 14:10:03 $
##
##      $Log: fuji_pg_chk_fep_mirroring_status.sh,v $
##
# Revision 1.0  2019/06/06 14:10:03  fijyrrose ()
# Eka versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_chk_fep_mirroring_status.sh

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

mc_ctl status >> $LOGFILE 2>&1
mc_ctl status  | grep -A2 "mirroring status" | tail -n 1 | egrep "not-switchable|unknown|failover-disabled" 
if [ $? -eq 0 ]
then
  echo "1 ERROR in Mirroring status. Run mc_ctl status"
else 
  echo "0"
fi > $TMPFILE

grep "^0" $TMPFILE 1>/dev/null 2>&1
if [ $? != 0 ] 
then
  if chk_if_print_message "MAJOR"
  then
    cp $TMPFILE $WORKING_DIR/tmp/postgres_main_errors.out
    echo "MAJOR FEP_MIRRORIG_STATUS - problems with FEP mirroring" | \
    ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    /bin/rm -rf $TMPFILE
    exit '-1'
 fi # end if chk_if...
fi

fuji_subloppu >> $LOGFILE
# /bin/rm -rf $LOGFILE
/bin/rm -rf $TMPFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files
exit 0
