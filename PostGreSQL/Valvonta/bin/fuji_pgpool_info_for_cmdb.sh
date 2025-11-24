#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2016
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pgpool_info_for_cmdb.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Check pgpool status and role
##
##      $Author: rosenjyr $
##      $Date: 2015/12/23 14:10:03 $
##
##      $Log: fuji_pgpool_info_for_cmdb.sh,v $
##
# Revision 1.0   2015/12/23 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pgpool_info_for_cmdb.sh

# Load common definitions
if [ -f /home/fujitsu/conf/fuji_check_pgpool_common.sh ]
then
. /home/fujitsu/conf/fuji_check_pgpool_common.sh
else
exit 0
fi


if [ -z $pg_check_user ]
then
  echo "Luultavasti ei pgpool:a asennettuna"
  rm -f $WORKING_DIR/iclcheck/db_info_for_cmdb.pgpool
  exit 0
fi

RUNTIME_TMP2=$WORKING_DIR/tmp/$fuji_progname_base.tmp2
iostname="$(echo -e "$(hostname -s)" | tr -d '[[:space:]]')"
touch $RUNTIME_TMP2
cp /dev/null $RUNTIME_TMP2
cp /dev/null $WORKING_DIR/iclcheck/db_info_for_cmdb.pgpool

echo " " > $WORKING_DIR/log/$fuji_progname_base.log
$PSQL -h $iostname -p $pg_check_port -U $pg_check_user postgres -t -c "show pool_nodes;" 1> $RUNTIME_TMP2 2>&1
if [ $? != 0 ]
then
  cat $RUNTIME_TMP2 >> $WORKING_DIR/log/$fuji_progname_base.log
  if chk_if_print_pgpool_message "MAJOR"
  then
    echo "MAJOR PGPOOL alert - database node main information not available" | \
    ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
  exit 1
fi

primary_count=0
standby_count=0
node_id=""
hostname=""
port=""
status=""
lb_weight=""
role=""
IFS="|"
while read node_id hostname port status lb_weight role
do
  # Tutkitaan/sivuutetaan mahdollisen tyhja rivi
  if [ -z $status ]
  then
    continue
  fi

  echo "$node_id $hostname $port $status $lb_weight $role" >> $WORKING_DIR/log/$fuji_progname_base.log
  status="$(echo -e "${status}" | tr -d '[[:space:]]')"
  # Versiossa 3.5 on uusi sarake tyyliin " role   | select_cnt"
  $(echo "${role}" | grep -E "\|") > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    role="$(echo -e "${role}" | awk -F'|' '{print $1}' | tr -d '[[:space:]]')"
  else
    role="$(echo -e "${role}" | tr -d '[[:space:]]')"
  fi
  hostname="$(echo -e "${hostname}" | tr -d '[[:space:]]')"

  # Otetaan statustiedot talteen
  if [ "$status" = "status" ]
  then
    continue
  fi
  echo "$hostname | $role" >> $WORKING_DIR/iclcheck/db_info_for_cmdb.pgpool
done < $RUNTIME_TMP2

rm -f $TMPFILE 1>/dev/null 2>&1
rm -f $RUNTIME_TMP2 1>/dev/null 2>&1
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0


