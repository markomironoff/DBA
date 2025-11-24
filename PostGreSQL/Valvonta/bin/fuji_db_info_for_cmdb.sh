#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2016
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_db_info_for_cmdb.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Haetaan tietoja kannoista CMDB:hen talletettavaksi
##
##      $Author: rosenjyr $
##      $Date: 2016/12/08 14:10:03 $
##
##      $Log: fuji_db_info_for_cmdb.sh,v $
##
# Revision 1.0  2016/12/08 14:10:03  fijyrrose ()
# Eka versio.
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_db_info_for_cmdb.sh

# Debug
# export VFY_ALL=1

#  Load common routines
. /home/fujitsu/conf/fuji_pg_common.sh

DB_NAME_FILE=/home/fujitsu/iclcheck/db_info_for_cmdb.databases
DB_COUNT_FILE=/home/fujitsu/iclcheck/db_info_for_cmdb.db_count
DB_MASTER_FILE=/home/fujitsu/iclcheck/db_info_for_cmdb.standbys
DB_STANDBYS_FILE=/home/fujitsu/iclcheck/db_info_for_cmdb.master
DB_BACKUP_FILE=/home/fujitsu/iclcheck/db_info_for_cmdb.backups

TMP_FILE=/tmp/db_info.tmp


# Database names and sizes:
touch $TMP_FILE
>$TMP_FILE
# /home/fujitsu/bin/fuji_pg_chk_db_status.sh | grep -v -E "fuji_dba_db|postgres|template1" | awk '{print $2 " " $3}' 1>$TMP_FILE
$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
  exit '-1'
fi

DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
/bin/rm -rf $TMPFILE

for database in $DBS; do
    $PSQL $PG_CONNECT_OPTS -l $database 1>$TMPFILE 2>&1
    if [ $? != 0 ]
    then
      exit '-1'
      /bin/rm -rf $TMPFILE
    fi
    echo "***   Database: $database available***" | grep -v -E "fuji_dba_db|postgres|template1" | awk '{print $2 " " $3}' >>$TMP_FILE
done
>$DB_NAME_FILE
IFS=$'\n'  
for line in  $(cat $TMP_FILE)
do
my_cmd=$(echo "$line" | awk -F": " '{ printf "psql -t -c \"SELECT pg_size_pretty(pg_database_size('\''%s'\''));\"\n", $2 }')
my_size=$(eval $my_cmd)
echo "$line | Size: $my_size" >> $DB_NAME_FILE
done

# Database counts:
wc -l $DB_NAME_FILE | awk '{print "Count: " $1}' 1> $DB_COUNT_FILE

# Replication master info:
rm -f $DB_MASTER_FILE
rm -f $TMP_FILE
psql -t -c 'SELECT client_addr, application_name from  pg_stat_replication;' | while read my_info
do     
  echo "$my_info" | tr -d ' ' >> $TMP_FILE
done

cat $TMP_FILE | sed '/^$/d' > $DB_MASTER_FILE
# Jos tyhja poistetaan
if [ ! -s $DB_MASTER_FILE ]
then
  rm -f $DB_MASTER_FILE
fi

# Replication standby info:
rm -f $DB_STANDBYS_FILE
if [ -f "$PGDATA/recovery.conf" ]
then
  egrep -i '^primary_conninfo|host' $PGDATA/recovery.conf | awk -F"=" '{print $3}' | awk '{print $1}' >$DB_STANDBYS_FILE
fi

# Backup info:
#
>$DB_BACKUP_FILE
# Dump:
BCK_CMD=$(crontab -l | grep -v "^#" | grep fuji_pg_dump | sed -e 's/[^sh]*$//')
if [ ! -z "$BCK_CMD" ]
then
BCK_DIR=$(grep "^DUMP_DIR" /home/fujitsu/conf/fuji_pg_common.sh)
echo "$BCK_CMD | $BCK_DIR" >>$DB_BACKUP_FILE
fi
# Online|basebackup:
BCK_CMD=$(crontab -l | grep -v "^#" | grep "backup" | egrep 'online|base' | sed -e 's/[^sh]*$//')
if [ ! -z "$BCK_CMD" ]
then
BCK_DIR=$(grep "^ONLINE_BACKUP_DIR" /home/fujitsu/conf/fuji_pg_common.sh)
echo "$BCK_CMD | $BCK_DIR" >>$DB_BACKUP_FILE
fi
# WAL-archive backup:
BCK_CMD=$(crontab -l | grep -v "^#" | grep "backup" | grep 'archive' | sed -e 's/[^sh]*$//')
if [ ! -z "$BCK_CMD" ]
then
BCK_DIR=$(grep "^WALL_ARC_DIR" /home/fujitsu/conf/fuji_pg_common.sh)
echo "$BCK_CMD | $BCK_DIR" >>$DB_BACKUP_FILE
fi

# Jos tyhja poistetaan
if [ ! -s $DB_BACKUP_FILE ]
then
  rm -f $DB_BACKUP_FILE
fi

/bin/rm -rf $LOGFILE
/bin/rm -rf $TMPFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files
exit 0
