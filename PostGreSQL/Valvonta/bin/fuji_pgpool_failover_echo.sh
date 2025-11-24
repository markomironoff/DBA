#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2012 - 2016
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pgpool_failover_echo.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan pgpool.conf:ssa failover_command:in kautta 
##                Tama versio kirjoittaa ainoastaa lokituksia - ei tee failoveria
##
##      $Author: rosenjyr $
##      $Date: 2016/02/26 10:14:05 $
##
##      $Log: fuji_pgpool_failover_echo.sh,v $
##
# Revision 1.0  2016/02/26 10:14:05 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pgpool_failover_echo.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_check_pgpool_common.sh

DATE=$(date "+%Y%m%d")

touch $LOGFILE
fuji_subalku > $LOGFILE

failed_node=$1
new_master=$2
trigger_file=$4
old_primary=$3
echo "`date`" >> $LOGFILE
echo "[INFO] failed_node: $failed_node new_master: $new_master trigger_file: $trigger_file old_primary: $old_primary" >> $LOGFILE
# if standby goes down.
if [ $failed_node != $old_primary ]; then
    echo "[INFO] Slave node is down. Failover not triggred !" >> $LOGFILE
    # Nostetaan lipputiedostoon varoitus 
    echo "WARNING PGPOOL alert - Slave node is down. Failover not triggred" >$WORKING_DIR/log/$fuji_progname_base.log
    echo "WARNING PGPOOL alert - Slave node is down. Failover not triggred" | \
    ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    exit 0;
fi


# Create the trigger file if primary node goes down.
echo "[INFO] Master node is down. Performing failover..." >> $LOGFILE

# Nostetaan lipputiedostoon halytys 
echo "MAJOR PGPOOL alert -  Master node is down. Performing failover from $failed_node to $new_master" >$WORKING_DIR/log/$fuji_progname_base.log
echo "MAJOR PGPOOL alert -  Master node is down. Performing failover from $failed_node to $new_master" | \
${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base

exit 1
