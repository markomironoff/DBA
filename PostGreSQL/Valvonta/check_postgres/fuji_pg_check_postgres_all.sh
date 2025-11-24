#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_allsh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan kaikki maaritellyt check_postgres rutiinit
##
##      $Author: rosenjyr $
##      $Date: 2015/12/28 10:31:33 $
##
##      $Log: fuji_pg_check_postgres_all.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1   2015/12/28 10:31:33 fijyrrose ()
# Lisatty transaction wraparound tarkistus:
# fuji_pg_check_postgres_txn_wraparound.sh 
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/check_postgres/fuji_pg_check_postgres_all.sh

/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_connection.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_archive_ready.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_backends.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_bloat.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_database_size.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_disk_space.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_last_vacuum.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_locks.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_query_time.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_relation_size.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_txn_idle.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_wal_files.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_query_runtime.sh show
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_txn_wraparound.sh show
# Kommentoi seuraava ellei ole replikoitu ymparisto
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row.sh show
