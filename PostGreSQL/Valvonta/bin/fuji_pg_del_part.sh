#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2018 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_del_part.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Poistetaan partitiointitauluja
##      Voidaan poistaa minka hyvansa taulun partitioita kirjoittamalla
##      poistologiikka pl/pgsql funktioon delete_partitions
##
##      $Author: rosenjyr $
##      $Date: 2019/02/06 12:20:10 $
##
##      $Log: fuji_pg_del_part.sh,v $
##
# Revision 1.0  2018/08/24 14:44:41 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2019/02/06 12:20:10 fijyrrose ()
# Poistetaan partitiot yksitellen ja tutkitaan niiden lukitustilanne,
# sek▒ lisatty partitioiden poistoon statement_timeout
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_del_part.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

DATE=$(date "+%Y%m%d")

touch $LOGFILE
fuji_subalku > $LOGFILE

if [ $# -lt 4 ]
then
    if chk_if_print_message "MAJOR"
    then
        echo "Aja komento:  fuji_pg_del_part.sh database del_interval day|month timeout" >> $LOGFILE
        echo "MAJOR PG_PARTITION_MAINTENANCE alert - Illegal number of parameters" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
#        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    if chk_if_print_message "MAJOR"
    then
        echo "MAJOR PG_PARTITION_MAINTENANCE alert - can not get database information" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi
database=$1
del_interval=$2
selector=$3
stat_timeout=$4

is_in_recovery=$($PSQL $PG_CONNECT_OPTS -t -c 'SELECT pg_is_in_recovery()')
if [ "$is_in_recovery" = " t" ]
then
  echo "PostgreSQL is in recovery. Exiting."  >> $LOGFILE
  echo "0" > $patrol_file
  exit 0
fi

for tbl_name  in $($PSQL $PG_CONNECT_OPTS -t $database -c "SELECT tablename FROM pg_tables WHERE schemaname = 'partitions' order by tablename")
do
#   echo "TBL_NAME: $tbl_name"
if [ "$selector" = "day" ]
then
  maint_command="SELECT delete_partitions('$del_interval days', 'day', '$tbl_name');"
elif [ "$selector" = "month" ]
then
  maint_command="SELECT delete_partitions('$del_interval months', 'month', '$tbl_name');"
else
    if chk_if_print_message "MAJOR"
    then
        echo "MAJOR PG_PARTITION_MAINTENANCE alert - Illegal selector. Use day or month"  >> $LOGFILE
        echo "MAJOR PG_PARTITION_MAINTENANCE alert - Illegal selector. Use day or month"  | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

#echo "maint_command $maint_command"

RUN_PSQL="$PSQL $PG_CONNECT_OPTS -v ON_ERROR_STOP=1 $database"



# $PSQL $PG_CONNECT_OPTS $database -c "$maint_command" >> $LOGFILE 2>&1
$RUN_PSQL <<SQL_END >> $LOGFILE 2>&1
set statement_timeout to $stat_timeout;
$maint_command
SQL_END

if [ $? != 0 ]
then
    if chk_if_print_message "MAJOR"
    then
        echo "MAJOR PG_PARTITION_MAINTENANCE alert - Error in removing partition"  >> $LOGFILE
        echo "MAJOR PG_PARTITION_MAINTENANCE alert -  Error in removing partition"  | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi
done
# echo Success! "
fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0

