#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_pgpool_status.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Check pgpool status and role
##
##      $Author: rosenjyr $
##      $Date: 2019/05/09 14:40:09 $
##
##      $Log: fuji_pg_check_pgpool_status.sh,v $
##
# Revision 1.0   2015/12/23 14:10:03 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1   2019/05/09 14:40:09 fijyrrose ()
# Lisatty timeout psql komennoille
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_pgpool/fuji_pg_check_pgpool_status.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_pgpool_common.sh

RUNTIME_STATUS_TMP=$WORKING_DIR/tmp/$fuji_progname_base.stat_tmp
touch $RUNTIME_STATUS_TMP
RUNTIME_ROLE_TMP=$WORKING_DIR/tmp/$fuji_progname_base.role_tmp
touch $RUNTIME_ROLE_TMP
RUNTIME_TMP2=$WORKING_DIR/tmp/$fuji_progname_base.tmp2
iostname="$(echo -e "${hostname}" | tr -d '[[:space:]]')"
touch $RUNTIME_TMP2
timeout_sec=$COMMAND_TIMEOUT
echo " " > $WORKING_DIR/log/$fuji_progname_base.log
    iostname="$(echo -e "${hostname}" | tr -d '[[:space:]]')"
IFS=","
for my_hostname in $PGPOOL_HOSTS
do 
cp /dev/null $RUNTIME_STATUS_TMP
cp /dev/null $RUNTIME_ROLE_TMP
cp /dev/null $RUNTIME_TMP2
IFS="|"
  echo -e "\n**** PGPOOL-II host: $my_hostname" >> $WORKING_DIR/log/$fuji_progname_base.log
  timeout $timeout_sec $PSQL  -v ON_ERROR_STOP=1 -h $my_hostname -p $pg_check_port -U $pg_check_user fuji_dba_db -c "show pool_nodes;" 1> $RUNTIME_TMP2 2>&1
  if [ $? != 0 ]
  then
    cat $RUNTIME_TMP2 >> $WORKING_DIR/log/$fuji_progname_base.log
    if chk_if_print_pgpool_message "MAJOR"
    then
      echo "MAJOR PGPOOL alert - database node main information not available" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    break
    fi

  primary_count=0
  standby_count=0
  node_id=""
  hostname=""
  port=""
  status=""
  lb_weight=""
  role=""
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
    # Statustiedot
    # 0 - This state is only used during the initialization. PCP will never display it.
    # 1 - Node is up. No connections yet.
    # 2 - Node is up. Connections are pooled.
    # 3 - Node is down.
    if [ "$status" = "down" ]
    then
     echo "$hostname" > $RUNTIME_STATUS_TMP
    fi

    # Oteteaan roolitiedot talteen
    if [ "$role" = "primary" ]
    then
     primary_count=$(( $primary_count + 1 ))
     echo "$hostname" >> $RUNTIME_ROLE_TMP
    fi
    if [ "$role" = "standby" ]
    then
     standby_count=$(( $standby_count + 1 ))
    fi

  done < $RUNTIME_TMP2

  my_status=$(cat $RUNTIME_STATUS_TMP | wc -l)
  my_db_hostname=$(cat $RUNTIME_STATUS_TMP)
  # Role tiedot:
  # echo "primary_count: $primary_count"
  if [ $primary_count -ne 1 ]
  then
    echo -e "$COL_RED**** MAJOR PGPOOL alert - PGPOOL in $my_hostname problems with primary db-node$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
    if chk_if_print_pgpool_message "MAJOR"
    then
      echo "MAJOR PGPOOL alert - PGPOOL in $my_hostname problems with primary db-node" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      exit 1
      # break
    fi # end if chk_if...
  fi

  # Jos useampi kuin 1 node on statuksella 3 ei pgpool <-> backend yhteydet toimi mihinkaan
  if [ $my_status -gt 1 ]
  then
    echo -e "$COL_RED**** MAJOR PGPOOL - $my_hostname problems with node $my_db_hostname status$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
    if chk_if_print_pgpool_message "WARNING"
    then
      echo "MAJOR PGPOOL - $my_hostname problems with node status" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      exit 1
      # break
    fi # end if chk_if...
  fi

  if [ $my_status -gt 0 ]
  then
    echo -e "$COL_RED**** WARNING PGPOOL - $my_hostname problems with node $my_db_hostname status$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
    if chk_if_print_pgpool_message "WARNING"
    then
      echo "WARNING PGPOOL - $my_hostname problems with node status" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
      exit 1
      # break
    fi # end if chk_if...
  fi

  host_count=$(( $host_count + 1 ))
done

# Tarkistetaan viela etta kaikilla pgpool nodeilla on kaytossa sama primary backend
uniq_primary_hosts_count=$(cat $RUNTIME_ROLE_TMP | uniq | wc -l)
if [ $uniq_primary_hosts_count -ne 1  ]
then
  echo -e "$COL_RED**** MAJOR PGPOOL alert - PGPOOL check primary db-nodes in pgpool servers$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
  if chk_if_print_pgpool_message "MAJOR"
  then
    echo "MAJOR PGPOOL alert - PGPOOL check primary db-nodes in pgpool servers" | \
    ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
  fi # end if chk_if...
fi

if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi

rm -f $TMPFILE 1>/dev/null 2>&1
rm -f $RUNTIME_STANDBY_TMP 1>/dev/null 2>&1
rm -f $RUNTIME_ROLE_TMP 1>/dev/null 2>&1
rm -f $RUNTIME_TMP2 1>/dev/null 2>&1
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0

