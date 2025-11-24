#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_every_10_minutes.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Koottu rutiinit jotka sopivat ajettavaksi (cronista) 10 min valein
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_every_10_minutes.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_every_10_minutes.sh

# When pg_xlog/archive_status/*.ready files count is beyond threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_archive_ready.sh show
# Disk space below threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_disk_space.sh show
# Any query running longer than threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_query_time.sh show
# Query in state "idle in transaction" for more than threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_txn_idle.sh show
# Check the total number of locks
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_locks.sh show
# Check if status query is runnin longer than threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_query_runtime.sh show
