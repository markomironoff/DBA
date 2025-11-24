#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_check_pgpool_all.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan kaikki maaritellyt check pgpool rutiinit
##
##      $Author: rosenjyr $
##      $Date:  2019/05/09 10:58:30 $
##
##      $Log: fuji_pg_check_pgpool_all.sh,v $
##
# Revision 1.0   2016/02/29 10:31:33 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1   2019/05/09 10:58:30 fijyrrose ()
# Poistettu fuji_pg_check_pgpool_connects.sh ja
# lisatty fuji_pg_check_pgpool_client_sessions.sh
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/check_pgpool/fuji_pg_check_pgpool_all.sh

/home/fujitsu/check_pgpool/check_routines/fuji_pg_check_pgpool_client_sessions.sh show
/home/fujitsu/check_pgpool/check_routines/fuji_pg_check_pgpool_status.sh show
