#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_once_a_day.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Koottu rutiinit jotka sopivat ajettavaksi (cronista) kerran vuorokaudessa
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_once_a_day.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_once_a_day.sh

# When tables/indexes bloated more then threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_bloat.sh show
# When database size is more then threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_database_size.sh show
# Checks how long it has been since vacuum (or analyze) was last run 
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_last_vacuum.sh show
# Checks for a relation that has grown too big
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_relation_size.sh show
# Checks how close to transaction wraparound one or more databases are getting
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_txn_wraparound.sh show
