#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2021
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_replicate_row.sh,v $
##      $Revision: 1.4 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres  rutiineita
##
##      $Author: rosenjyr $
##      $Date: 2021/11/03 11:25:10 $
##
##      $Log: fuji_pg_check_postgres_replicate_row.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
# Revision 1.3  2020/06/11 12:23:20  fijyrrose ()
# Paatellaan master ja standby kantojen tietoja
# ellei niita ole annettu konfigurointitiedoissa
#
# Revision 1.4  2021/11/03 11:25:10  fijyrrose ()
# Muutettu IP tietojen hakua pg_hba.conf tiedoista
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_replicate_row.sh

# Load common definitions
. /home/fujitsu/conf/fuji_check_postgres_common.sh

tmp_file="/home/fujitsu/tmp/replicate_row_$$"
standby_file="/home/fujitsu/tmp/replicate_standby"
dummy_file="/home/fujitsu/tmp/repl.dummy"

# Tutkitaan onko kanta standby roolissa jolloin ei ajeta tata
if chk_if_pg_is_in_recovery
then
  if [ "$1" = "show" ]
  then
    echo "$fuji_progname_base: PostgreSQL is in recovery. Exiting."
  fi
  exit 0
fi

# Koitetaan paatella IP:t ellei niita ole annettu konfigurointitiedoissa
if [ "$REPLICATE_ROW_MASTER_HOST" = "<REPLICATE_MASTER_HOST>" ] && [ "$REPLICATE_ROW_SLAVE_HOSTS" = "<REPLICATE_STANDBY_HOSTS>" ]; then
  if [ -f "$standby_file" ]; then
    time_minus_one_hour=$(date -d '1 hour ago' "+%Y%m%d%H%M")
    touch -t $time_minus_one_hour $dummy_file
    newer_file=$(find $standby_file -newer $dummy_file -type f -exec ls {} \;)
    if [ -z $newer_file ]; then
      standby_ip=$(psql -qAtX -c "select client_addr from pg_stat_replication")
      echo "$standby_ip" > $standby_file
    fi
    standby_ip=$(cat $standby_file)
    if [ -z $standby_ip ]; then
      standby_ip=$(psql -qAtX -c "select client_addr from pg_stat_replication")
      echo "$standby_ip" > $standby_file
    fi
  else
    standby_ip=$(psql -qAtX -c "select client_addr from pg_stat_replication")
#    standby_ip=$(psql -qAtX -c "select client_hostname from pg_stat_replication")
    echo "$standby_ip" > $standby_file
  fi
  if [ -z $standby_ip ]; then
#    echo "No replication"
    exit 0
  fi

  for PG_IP in $(grep "host" $PGDATA/pg_hba.conf | grep "fuji_dba" | awk '{print $4}' | awk -F'/' '{print $1'})
  do
#    echo $PG_IP
    for OS_IP in $(ifconfig | grep inet | grep -v inet6 | awk '{print $2}')
    do
      if [ "$PG_IP" == "$OS_IP" ]; then
        export master_ip=$PG_IP
        break
      fi
    done
  done
# echo "host_IP: $master_ip, standby_ip=$standby_ip"a
  REPLICATE_ROW_MASTER_HOST=$master_ip
  REPLICATE_ROW_SLAVE_HOSTS=$standby_ip
fi # end of if REPLICATE...

$CHECK_POSTGRES_DIR/check_postgres_replicate_row \
--host=$REPLICATE_ROW_MASTER_HOST --dbname=$REPLICATE_ROW_MASTER_DB \
--host=$REPLICATE_ROW_SLAVE_HOSTS --dbname=$REPLICATE_ROW_SLAVE_DB \
--repinfo=$REPLICATE_ROW_TABLE,$REPLICATE_ROW_PRIM_KEY_COL,$REPLICATE_ROW_PRIM_KEY_VALUE,$REPLICATE_ROW_COL_TO_CHANCE,\
$REPLICATE_ROW_FROM_VALUE,$REPLICATE_ROW_TO_VALUE \
--dbuser=$REPLICATE_ROW_DBUSER --dbpass=$REPLICATE_ROW_DBPASS \
--warning=$REPLICATE_ROW_WARNING --critical=$REPLICATE_ROW_CRITICAL   1> $tmp_file $2>&1
grep "^ERROR" $tmp_file 1>/dev/null 2>&1
if [ $? = 0 ]
then
my_tmp=$(echo "POSTGRES_REPLICATE_ROW CRITICAL")
my_tmp2=$(cat $tmp_file)
echo -e "$my_tmp $my_tmp2" | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
else
cat $tmp_file | \
. $FUJI_CHECK_POSTGRES_DIR/fuji_check_postgres_modify.sh | \
$WORKING_DIR/bin/collect_alarms.sh $fuji_progname_base
fi
rm $tmp_file

if [ "$1" = "show" ]
then
  cat $WORKING_DIR/log/$fuji_progname_base.log
fi

rm -f $TMPFILE 1>/dev/null 2>&1

