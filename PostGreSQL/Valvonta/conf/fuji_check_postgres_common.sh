#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2020
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_check_postgres_common.sh,v $
##      $Revision: 1.4 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleista check_postgres tyokalua hyodyntavien skripteihin liittyvat muuttujat
##
##      $Author: rosenjyr $
##      $Date: 2020/11/06 14:50:10 $
##
##      $Log: fuji_check_postgres_common.sh,v $
##
# Revision 1.1  2011/12/20 14:10:03  fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2   2015/11/03 16:40:13 fijyrrose ()
# Lisatty tarkistus josko instanssi onkin alhaalla
# -> ei tarvitse/kannata ajaa kaikkia tarkistuksia
#
# Revision 1.3   2015/12/23 07:11:13 fijyrrose ()
# Lisatty wraparound tarkistus
#
# Revision 1.4   2020/11/06 14:50:10 fijyrrose ()
# Kasvattettu halytysrajojen baselineja
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/conf/check_postgres/fuji_check_postgres_common.sh

# Base directory
WORKING_DIR=/home/fujitsu

# check_postgres routines directory
# kayta seuraavaa:CHECK_POSTGRES_DIR=/home/fujitsu/check_postgres/check_postgres-2.22.0
# jos Postgres versio on > 10 kayta seuraavaa
CHECK_POSTGRES_DIR=/home/fujitsu/check_postgres/check_postgres-2.24.0

# check_postgres fujitsu routines directory
FUJI_CHECK_POSTGRES_DIR=/home/fujitsu/check_postgres
# Load common definitions
. $WORKING_DIR/conf/fuji_pg_common.sh


# check_postgres alarm threshol values

## For check_postgres_wal_files
## min = checkpoint_segments * 2 + 1 (mutta laita reilusti enemman)
## kayta wal_keep_segments jos se on maaritelty ja suurempi kuin em. laskettu
WAL_FILES_WARNING=200
WAL_FILES_CRITICAL=400
## For check_postgres_archive_ready
## Naita kertyy jos esim arkistointi ei toimi
ARCHIVE_READY_WARNING=20
ARCHIVE_READY_CRITICAL=50
## For check_postgres_backends, eli max_connection arvosta kaytetyt
## Joko prosentteina, tai alle tietyn maaran vapaana (huom! merkinta -10 = alle 10 vapaana)
BACKENDS_WARNING="85%"
# Jos halutaan antaa ymparistokohtaisia arvoja
# BACKENDS_WARNINGinst1="75%"
BACKENDS_CRITICAL="95%"
## For check_postgres_bloat
## Joko prosentteina ja/tai alle tietyn koon
## huom! nayttaisi etta esim luku 400% vastaisi 4X tilanvarausta
BLOAT_WARNING="110% and 600M"
BLOAT_CRITICAL="220% and 1000M"
## For check_postgres_connection, tarkistetaan etta kannat ovat ylhaalla
CONNECTION_DBNAME=postgres
## For check_postgres_database_size
DATABASE_SIZE_WARNING="300G"
DATABASE_SIZE_CRITICAL="800G"
## For check_postgres_disk_space
## Tarkistetaan data, loki, WAL-loki, taulualue levyt
DISK_SPACE_WARNING="90%"
DISK_SPACE_CRITICAL="95%"
## For check_postgres_relation_size - yksittaisen taulun tai indeksin koko
RELATION_SIZE_WARNING="10G"
RELATION_SIZE_CRITICAL="50G"
## For check_postgres_last_vacuum
## esim. 120m (120min), 14d (14 date)
LAST_VACUUM_WARNING="180d"
LAST_VACUUM_CRITICAL="360d"
# Tietokannat joita ei tutkita, erota lista |-merkilla, esim. template1|postgres
LAST_VACUUM_EXCLUDEDB="template1|postgres"
## For check_postgres_locks
#LOCKS_WARNING="200"
LOCKS_WARNING="total=1200;waiting=4"
# LOCKS_CRITICAL="500"
LOCKS_CRITICAL="total=4000;waiting=10"
## For check_postgres_query_time - ajossa olevien kyselyjen kestot
QUERY_TIME_WARNING="10m"
QUERY_TIME_CRITICAL="2h"
# QUERY_TIME_WARNING="60m"
# QUERY_TIME_CRITICAL="6h"
## For check_postgres_tnx_idle
## Idle transactions
TXN_IDLE_WARNING="10m"
TXN_IDLE_CRITICAL="2h"
## For check_postgres_replicate_row
## kts. taman vaatimat asennukset kantaan varmistukset ja valvonta dokumentista
REPLICATE_ROW_WARNING="20"
REPLICATE_ROW_CRITICAL="120"
REPLICATE_ROW_MASTER_HOST="172.31.179.71"
REPLICATE_ROW_MASTER_DB="fuji_dba_db"
# Seuraavaan voi antaa useampia slave tietoja (pilkulla erotettuna)
REPLICATE_ROW_SLAVE_HOSTS="172.31.179.72"
REPLICATE_ROW_SLAVE_DB=$REPLICATE_ROW_MASTER_DB
REPLICATE_ROW_TABLE="fuji_check_status"
REPLICATE_ROW_PRIM_KEY_COL="id"
REPLICATE_ROW_PRIM_KEY_VALUE="1"
REPLICATE_ROW_COL_TO_CHANCE="col1"
REPLICATE_ROW_FROM_VALUE="from_val"
REPLICATE_ROW_TO_VALUE="to_val"
REPLICATE_ROW_DBUSER="fuji_dba"
REPLICATE_ROW_DBPASS="BDCHYr9t1cYj4adGyvI3"
## For check_postgres_query_runtime
## tehdaan kysely maarattyyn tauluun
QUERY_RUNTIME_WARNING="10"
QUERY_RUNTIME_CRITICAL="60"
QUERY_RUNTIME_QUERYNAME="fuji_check_status"
QUERY_RUNTIME_DBNAME="fuji_dba_db"
## For check_postgres_txn_wraparound
## Jollei naita maaritella kaytetaan oletuksia
## warning 1.3 miljardia (1_300_000_000)
## critical 1.7 miljardia (1_700_000_000)
TXN_WRAPAROUND_WARNING=
TXN_WRAPAROUND_CRITICAL=

# Tarkistus josko instanssi on alhaalla jolloin ei tarkistuksia kannata tehda
if [ -f $WORKING_DIR/tmp/check_postgres_db_down ]
then
  exit 0
fi


##########################################################
# Asetataan mahdolliset instanssikohtaiset valvonta-arvot
###########################################################
if [ -z $(eval echo \$\{WAL_FILES_WARNING$PG_SID\}) ]
then
WAL_FILES_WARNING=$WAL_FILES_WARNING
else
WAL_FILES_WARNING=$(eval echo \$\{WAL_FILES_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{WAL_FILES_CRITICAL$PG_SID\}) ]
then
WAL_FILES_CRITICAL=$WAL_FILES_CRITICAL
else
WAL_FILES_CRITICAL=$(eval echo \$\{WAL_FILES_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{ARCHIVE_READY_WARNING$PG_SID\}) ]
then
ARCHIVE_READY_WARNING=$ARCHIVE_READY_WARNING
else
ARCHIVE_READY_WARNING=$(eval echo \$\{ARCHIVE_READY_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{ARCHIVE_READY_CRITICAL$PG_SID\}) ]
then
ARCHIVE_READY_CRITICAL=$ARCHIVE_READY_CRITICAL
else
ARCHIVE_READY_CRITICAL=$(eval echo \$\{ARCHIVE_READY_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{BACKENDS_WARNING$PG_SID\}) ]
then
BACKENDS_WARNING=$BACKENDS_WARNING
else
BACKENDS_WARNING=$(eval echo \$\{BACKENDS_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{BACKENDS_CRITICAL$PG_SID\}) ]
then
BACKENDS_CRITICAL=$BACKENDS_CRITICAL
else
BACKENDS_CRITICAL=$(eval echo \$\{BACKENDS_CRITICAL$PG_SID\})
fi
my_var=$(eval echo \$\{BLOAT_WARNING$PG_SID\})
# if [ -z $(eval echo \$\{BLOAT_WARNING$PG_SID\}) ]
if [ -z "$my_var" ]
then
BLOAT_WARNING=$BLOAT_WARNING
else
BLOAT_WARNING=$(eval echo \$\{BLOAT_WARNING$PG_SID\})
fi
my_var=$(eval echo \$\{BLOAT_CRITICAL$PG_SID\})
if [ -z "$my_var" ]
then
BLOAT_CRITICAL=$BLOAT_CRITICAL
else
BLOAT_CRITICAL=$(eval echo \$\{BLOAT_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{CONNECTION_DBNAME$PG_SID\}) ]
then
CONNECTION_DBNAME=$CONNECTION_DBNAME
else
CONNECTION_DBNAME=$(eval echo \$\{CONNECTION_DBNAME$PG_SID\})
fi
if [ -z $(eval echo \$\{DATABASE_SIZE_WARNING$PG_SID\}) ]
then
DATABASE_SIZE_WARNING=$DATABASE_SIZE_WARNING
else
DATABASE_SIZE_WARNING=$(eval echo \$\{DATABASE_SIZE_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{DATABASE_SIZE_CRITICAL$PG_SID\}) ]
then
DATABASE_SIZE_CRITICAL=$DATABASE_SIZE_CRITICAL
else
DATABASE_SIZE_CRITICAL=$(eval echo \$\{DATABASE_SIZE_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{DISK_SPACE_WARNING$PG_SID\}) ]
then
DISK_SPACE_WARNING=$DISK_SPACE_WARNING
else
DISK_SPACE_WARNING=$(eval echo \$\{DISK_SPACE_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{DISK_SPACE_CRITICAL$PG_SID\}) ]
then
DISK_SPACE_CRITICAL=$DISK_SPACE_CRITICAL
else
DISK_SPACE_CRITICAL=$(eval echo \$\{DISK_SPACE_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{RELATION_SIZE_WARNING$PG_SID\}) ]
then
RELATION_SIZE_WARNING=$RELATION_SIZE_WARNING
else
RELATION_SIZE_WARNING=$(eval echo \$\{RELATION_SIZE_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{RELATION_SIZE_CRITICAL$PG_SID\}) ]
then
RELATION_SIZE_CRITICAL=$RELATION_SIZE_CRITICAL
else
RELATION_SIZE_CRITICAL=$(eval echo \$\{RELATION_SIZE_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{LAST_VACUUM_WARNING$PG_SID\}) ]
then
LAST_VACUUM_WARNING=$LAST_VACUUM_WARNING
else
LAST_VACUUM_WARNING=$(eval echo \$\{LAST_VACUUM_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{LAST_VACUUM_CRITICAL$PG_SID\}) ]
then
LAST_VACUUM_CRITICAL=$LAST_VACUUM_CRITICAL
else
LAST_VACUUM_CRITICAL=$(eval echo \$\{LAST_VACUUM_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{LAST_VACUUM_EXCLUDEDB$PG_SID\}) ]
then
LAST_VACUUM_EXCLUDEDB=$LAST_VACUUM_EXCLUDEDB
else
LAST_VACUUM_EXCLUDEDB=$(eval echo \$\{LAST_VACUUM_EXCLUDEDB$PG_SID\})
fi
if [ -z $(eval echo \$\{LOCKS_WARNING$PG_SID\}) ]
then
LOCKS_WARNING=$LOCKS_WARNING
else
LOCKS_WARNING=$(eval echo \$\{LOCKS_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{LOCKS_CRITICAL$PG_SID\}) ]
then
LOCKS_CRITICAL=$LOCKS_CRITICAL
else
LOCKS_CRITICAL=$(eval echo \$\{LOCKS_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_TIME_WARNING$PG_SID\}) ]
then
QUERY_TIME_WARNING=$QUERY_TIME_WARNING
else
QUERY_TIME_WARNING=$(eval echo \$\{QUERY_TIME_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_TIME_CRITICAL$PG_SID\}) ]
then
QUERY_TIME_CRITICAL=$QUERY_TIME_CRITICAL
else
QUERY_TIME_CRITICAL=$(eval echo \$\{QUERY_TIME_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{TXN_IDLE_WARNING$PG_SID\}) ]
then
TXN_IDLE_WARNING=$TXN_IDLE_WARNING
else
TXN_IDLE_WARNING=$(eval echo \$\{TXN_IDLE_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{TXN_IDLE_CRITICAL$PG_SID\}) ]
then
TXN_IDLE_CRITICAL=$TXN_IDLE_CRITICAL
else
TXN_IDLE_CRITICAL=$(eval echo \$\{TXN_IDLE_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{REPLICATE_ROW_WARNING$PG_SID\}) ]
then
REPLICATE_ROW_WARNING=$REPLICATE_ROW_WARNING
else
REPLICATE_ROW_WARNING=$(eval echo \$\{REPLICATE_ROW_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{REPLICATE_ROW_CRITICAL$PG_SID\}) ]
then
REPLICATE_ROW_CRITICAL=$REPLICATE_ROW_CRITICAL
else
REPLICATE_ROW_CRITICAL=$(eval echo \$\{REPLICATE_ROW_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{REPLICATE_ROW_MASTER_HOST$PG_SID\}) ]
then
REPLICATE_ROW_MASTER_HOST=$REPLICATE_ROW_MASTER_HOST
else
REPLICATE_ROW_MASTER_HOST=$(eval echo \$\{REPLICATE_ROW_MASTER_HOST$PG_SID\})
fi
if [ -z $(eval echo \$\{REPLICATE_ROW_SLAVE_HOSTS$PG_SID\}) ]
then
REPLICATE_ROW_SLAVE_HOSTS=$REPLICATE_ROW_SLAVE_HOSTS
else
REPLICATE_ROW_SLAVE_HOSTS=$(eval echo \$\{REPLICATE_ROW_SLAVE_HOSTS$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_RUNTIME_WARNING$PG_SID\}) ]
then
QUERY_RUNTIME_WARNING=$QUERY_RUNTIME_WARNING
else
QUERY_RUNTIME_WARNING=$(eval echo \$\{QUERY_RUNTIME_WARNING$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_RUNTIME_CRITICAL$PG_SID\}) ]
then
QUERY_RUNTIME_CRITICAL=$QUERY_RUNTIME_CRITICAL
else
QUERY_RUNTIME_CRITICAL=$(eval echo \$\{QUERY_RUNTIME_CRITICAL$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_RUNTIME_QUERYNAME$PG_SID\}) ]
then
QUERY_RUNTIME_QUERYNAME=$QUERY_RUNTIME_QUERYNAME
else
QUERY_RUNTIME_QUERYNAME=$(eval echo \$\{QUERY_RUNTIME_QUERYNAME$PG_SID\})
fi
if [ -z $(eval echo \$\{QUERY_RUNTIME_DBNAME$PG_SID\}) ]
then
QUERY_RUNTIME_DBNAME=$QUERY_RUNTIME_DBNAME
else
QUERY_RUNTIME_DBNAME=$(eval echo \$\{QUERY_RUNTIME_DBNAME$PG_SID\})
fi

