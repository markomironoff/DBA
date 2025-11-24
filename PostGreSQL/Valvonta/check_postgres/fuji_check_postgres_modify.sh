#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_check_postgres_modify.sh,v $
##      $Revision: 1.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Muotoilee check_postgres rutiineiden lahettaman ilmoituksen
##
##      $Author: rosenjyr $
##      $Date: 2015/09/17 14:10:03 $
##
##      $Log: fuji_check_postgres_modify.sh,v $
##
# Revision 1.0   2015/09/17 14:10:03 fijyrrose ()
# Ensimmainen versio
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/check_postgres/fuji_check_postgres_modify.sh
# Viestissa voi olla useita riveja.
while read line
do
  # Otetaan ensimmainen rivi talteen (siina on status ja kohdetiedot - viela ei kayttoa mutta voi tulla)
  if [ -z "${first_line}" ]
  then
    first_line=$line
  fi
  msg_tmp=`echo -e "${msg_tmp}${line}\n"`
done

msg=$(echo "${msg_tmp}")
# echo -e "$msg" | awk '{print $2" PGCHECK " $0 }'
echo "$msg" | awk '{print $2" PGCHECK " $0 }' | sed 's/://' | sed 's/;/,/g' | tee $WORKING_DIR/log/$fuji_progname_base.log
# echo -e "${first_line}" | awk '{print $2" PGCHECK " $0 }' | tee $WORKING_DIR/log/$fuji_progname_base.log
