#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_postgres_every_1_minute.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Koottu rutiinit jotka sopivat ajettavaksi (cronista) 1 min valein
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_pg_check_postgres_every_1_minute.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/check_postgres/fuji_pg_check_postgres_every_1_minute.sh

# When postgres instance is not running
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_connection.sh show
# When number of connections crosses threshold
/home/fujitsu/check_postgres/check_routines/fuji_pg_check_postgres_backends.sh show
