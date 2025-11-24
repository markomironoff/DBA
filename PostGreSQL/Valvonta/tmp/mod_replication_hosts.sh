#!/bin/bash

. $HOME/pg.env
pg_isready 1>/dev/null 2>&1
return_code=$?
if [ $return_code -ne 0 ]; then
  exit $return_code
fi

# Find out replication roles
IN_RECOVERY=$(psql -d postgres -v "ON_ERROR_STOP=on" -t -c 'SELECT pg_is_in_recovery()')
case ${IN_RECOVERY// /} in
( f )
streaming_standby=$(psql -d postgres -v "ON_ERROR_STOP=on" -t -c "SELECT client_addr FROM pg_stat_replication" | grep -v "^$")
if [ -z "$streaming_standby" ]; then
  sed -i  "s%/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row%#/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row%g" /home/fujitsu/check_postgres/fuji_pg_check_postgres_all.sh
  sed -i  "s%/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row%#/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row%g" /home/fujitsu/check_postgres/fuji_pg_check_postgres_every_5_minutes.sh
  exit 0
fi
streaming_host="172.31.179.71"
;;
( t )
streaming_host="172.31.179.71"
streaming_standby=$(cat $PGDATA/recovery.conf |awk -F'host=' '{print $2}' | awk '{print $1}' | grep -v "^$")
;;
esac

sed -i "s/<REPLICATE_MASTER_HOST>/$streaming_host/g" /home/fujitsu/conf/fuji_check_postgres_common.sh
sed -i "s/<REPLICATE_STANDBY_HOSTS>/$streaming_standby/g" /home/fujitsu/conf/fuji_check_postgres_common.sh

grep "^# For replication monitoring" $PGDATA/pg_hba.conf >/dev/null 2>&1
if [ $? -eq 0 ]; then
  exit 0
fi
echo "# For replication monitoring" >>$PGDATA/pg_hba.conf
echo "host  fuji_dba_db     fuji_dba     ${streaming_standby}/32 md5" >>$PGDATA/pg_hba.conf
echo "host  fuji_dba_db     fuji_dba     ${streaming_host}/32    md5" >>$PGDATA/pg_hba.conf
pg_ctl reload

exit 0

