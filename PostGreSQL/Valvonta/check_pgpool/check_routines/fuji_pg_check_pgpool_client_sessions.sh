#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_pgpool_client_sessions.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: check pgpool client sessions (num_init_children)
##
##      $Author: rosenjyr $
##      $Date: 2019/05/09 14:10:03 $
##
##      $Log: fuji_pg_check_pgpool_client_sessions.sh,v $
##
# Revision 1.0   2019/05/09 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_pgpool/check_routines/fuji_pg_check_pgpool_client_sessions.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_pgpool_common.sh

# Variables for backend connections (max. 6 backends)
node_count0=0
node_count1=0
node_count2=0
node_count3=0
node_count4=0
node_count5=0
node_count6=0
# dynamic value for counters
dyn_value=0

# Timeout for psql excecute
timeout_sec=$COMMAND_TIMEOUT

RUNTIME_TMP2=$WORKING_DIR/tmp/$fuji_progname_base.tmp2
RUNTIME_TMP3=$WORKING_DIR/tmp/$fuji_progname_base.tmp3

if [ -z $NUM_INIT_CHILDREN_WARNING ]
then
  NUM_INIT_CHILDREN_WARNING="85%"
fi
if [ -z $NUM_INIT_CHILDREN_CRITICAL ]
then
  NUM_INIT_CHILDREN_CRITICAL="95%"
fi

echo " " > $WORKING_DIR/log/$fuji_progname_base.log
# Float juttujen takia pitaa kikkailla awk:lla kun kaikissa ymparistoissa 
# ei valttamatta ole bc asennettuna (jolla olisi helpompi hoitaa homma)
my_num_init_children=$(echo "$num_init_children" | awk '{printf "%.1f", $1}')
my_tmp=0.0

if [ $(echo $NUM_INIT_CHILDREN_WARNING | grep "%") ]
then
  warning_percentage=$(echo $NUM_INIT_CHILDREN_WARNING | tr -d "%" | awk '{printf "%.1f", $1}')
  my_tmp=$(awk -v t1="$my_num_init_children" -v t2="$warning_percentage" 'BEGIN{printf "%.1f",  t1 * t2 / 100.0}')
  warning_level=$(awk -v t1="$my_num_init_children" -v t2="$my_tmp" 'BEGIN{printf "%.1f",  t1 - t2}')
else
  warning_level=$NUM_INIT_CHILDREN_WARNING
fi
if [ $(echo $NUM_INIT_CHILDREN_CRITICAL | grep "%") ]
then
  critical_percentage=$(echo $NUM_INIT_CHILDREN_CRITICAL | tr -d "%" | awk '{printf "%.1f", $1}')
  my_tmp=$(awk -v t1="$my_num_init_children" -v t2="$critical_percentage" 'BEGIN{printf "%.1f",  t1 * t2 / 100}')
  critical_level=$(awk -v t1="$my_num_init_children" -v t2="$my_tmp" 'BEGIN{printf "%.1f",  t1 - t2}')
else
  critical_level=$NUM_INIT_CHILDREN_CRITICAL
fi

touch $RUNTIME_TMP2
touch $RUNTIME_TMP3
echo " " > $WORKING_DIR/log/$fuji_progname_base.log
cp /dev/null $RUNTIME_TMP2
cp /dev/null $RUNTIME_TMP3
how_many_nodes=0
IFS=","
for my_hostname in $PGPOOL_HOSTS
do  
  echo -e "\n**** PGPOOL-II host: $my_hostname" > $WORKING_DIR/log/$fuji_progname_base.log
  timeout $timeout_sec $PSQL -v ON_ERROR_STOP=1 -h $my_hostname -p $pg_check_port -U $pg_check_user fuji_dba_db -c "show pool_nodes" | egrep -v "rows|lb_weight|\+|^$" 1> $RUNTIME_TMP3 2>&1
  if [ $? != 0 ]
  then
    cat $RUNTIME_TMP3 >> $WORKING_DIR/log/$fuji_progname_base.log
    if chk_if_print_pgpool_message "MAJOR"
    then
      echo "MAJOR PGPOOL alert - database node main information not available" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    break
    fi
#    cat $RUNTIME_TMP3
    how_many_nodes=$($PSQL -h $my_hostname -p $pg_check_port -U $pg_check_user fuji_dba_db -c "show pool_nodes" | egrep -v "rows|lb_weight|\+|^$" | wc -l)
  IFS="|"
  timeout $timeout_sec $PSQL -h $my_hostname -p $pg_check_port -U $pg_check_user fuji_dba_db -c "show pool_pools" | egrep -v "rows|pool_backendpid|\+|^$" 1> $RUNTIME_TMP2 2>&1
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

  dyn_value=0
  while read pool_pid start_time pool_id backend_id database username create_time majorversion minorversion pool_counter pool_backendpid pool_connected
  do
    # Tutkitaan/sivuutetaan mahdollisen tyhja rivi
    if [ -z $pool_pid ]
    then
      continue
    fi
    var_no_whitespaces="$(echo -e "${backend_id}" | tr -d '[:space:]')"
    dyn_value="node_count${var_no_whitespaces}"
    my_tmp=${!dyn_value}
    var_no_whitespaces="$(echo -e "${pool_connected}" | tr -d '[:space:]')"
    my_tmp=$(( $my_tmp + $var_no_whitespaces ))
    eval ${dyn_value}=$my_tmp 

  done < $RUNTIME_TMP2

# Float lukujen takia seuraavat "kikkailut"
my_how_many_nodes=$(echo "$how_many_nodes" | awk '{printf "%.1f", $1}')=
my_max_pool=$(echo "$max_pool" | awk '{printf "%.1f", $1}')=
# my_connections_all=$(awk -v t1="$my_num_init_children" -v t2="$my_max_pool" 'BEGIN{printf "%.1f",  t1 * t2}')
my_connections_all=$my_num_init_children
# my_connected_count=$(echo "$connected_count" | awk '{printf "%.1f", $1}')

for (( c=0; c<$how_many_nodes; c++ ))
do 
   echo -e "**** PGPOOL-II node: $c" >> $WORKING_DIR/log/$fuji_progname_base.log
   dyn_value="node_count${c}"
   my_connected_count=$(echo "${!dyn_value}" | awk '{printf "%.1f", $1}')
   free_connections=$(awk -v t1="$my_connections_all" -v t2="$my_connected_count" 'BEGIN{printf "%.1f",  t1 - t2}')
   critical_var=$(awk -v free_con=$free_connections -v level=$critical_level 'BEGIN{print free_con<=level?1:0}')
   warning_var=$(awk -v free_con=$free_connections -v level=$warning_level 'BEGIN{print free_con<=level?1:0}')

   if [ $critical_var -eq 1 ]
   then
     echo -e "$COL_RED**** MAJOR PGPOOL alert - PGPOOL free client sessions: $free_connections is less than level: $critical_level$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
     if chk_if_print_pgpool_message "MAJOR"
     then
      echo "MAJOR PGPOOL alert - PGPOOL free cwclient sessionsconnections: $free_connections is less than level: $critical_level" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
     fi # end if chk_if...
   elif [ $warning_var -eq 1 ]
   then
     echo -e "$COL_RED**** WARNING PGPOOL alert - PGPOOL free client sessions: $free_connections is less than level: $warning_level$COL_RESET" >> $WORKING_DIR/log/$fuji_progname_base.log
     if chk_if_print_pgpool_message "WARNING"
     then
       echo "WARNING PGPOOL alert - PGPOOL free client sessions: $free_connections is less than level: $warning_level" | \
       ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
     fi # end if chk_if...
   else
     echo -e "**** Max client sessions: $my_connections_all, Using: $(awk -v t1="$my_connections_all" -v t2="$free_connections" 'BEGIN {printf "%.1f", t1 - t2}'), Free client sessions: $free_connections  ***" >> $WORKING_DIR/log/$fuji_progname_base.log
   fi
   if [ "$1" = "show" ]
   then
     cat $WORKING_DIR/log/$fuji_progname_base.log
     >$WORKING_DIR/log/$fuji_progname_base.log
   fi
done # end of for (( c ... -loop

done < $RUNTIME_TMP3


rm -f $TMPFILE 1>/dev/null 2>&1
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files
exit 0
