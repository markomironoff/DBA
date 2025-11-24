#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2012 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: my_pg_archvecleanup.sh,v $
##      $Revision: 1.2 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Siivotuaan vanhentuneet PostgreSQL wal arkistotiedostot
##
##      $Author: rosenjyr $
##      $Date: 2015/05/05 14:10:03 $
##
##      $Log: my_pg_archvecleanup.sh,v $
##
# Revision 1.1  015/05/05 14:10:03  fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/my_pg_archvecleanup.sh

for f in $1/*; do
    [ $f -ot $1/$2 ] &&  {
       #  echo "$f is older" 
        rm -f $f 
    }
done
