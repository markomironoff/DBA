#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2012 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_rm_old_wal_arc_backup.sh,v $
##      $Revision: 1.2 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Siivotuaan vanhentuneet PostgreSQL wal arkistotiedostot
##
##      $Author: rosenjyr $
##      $Date: 2015/05/05 14:10:03 $
##
##      $Log: fuji_rm_old_wal_arc_backup.sh,v $
##
# Revision 1.1  015/05/05 14:10:03  fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_rm_old_wal_arc_backup.sh

online_ids=$(ls -ltr $1/*online* | rev | cut -d_ -f3 | rev | cut -d- -f1 | paste -sd "|" -)
for f in $(ls $1/*wall_arcs* | egrep -v "$online_ids") 
do
    [ "$f" -ot "$1/$2" ] &&  {
        echo "$f is older" 
        # rm -f $f 
    }
done
