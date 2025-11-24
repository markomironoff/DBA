#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_every_5_minutes.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Koottu rutiinit jotka sopivat ajettavaksi (cronista) 5 min valein
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_every_5_minutes.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_every_5_minutes.sh

# TODO: Check streamig cluster

# Checks how many WAL files exist in the pg_xlog directory
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_wal_files.sh show
# Checks that master-slave replication is working to one or more slaves
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_replicate_row.sh show
