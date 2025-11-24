#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2016
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_wal_arc_to_dir.sh,v $
##      $Revision: 1.2 $
##
##      /**** FOR LINUX ****/
##
##      Contents: PostgreSQL WAL lokien kopiointi arkistointi hakemistoon
##
##      HUOM! Maarittele postgres.conf tiedostoon:
##	archive_command = '/home/fujitsu/bin/fuji_pg_wal_arc_to_dir.sh %p %f'
##
##      $Author: rosenjyr $
##      $Date: 2016/12/08 09:46:10 $
##
##      $Log: fuji_pg_wal_arc_to_dir.sh,v $
#
# Revision 1.1  2015/05/04 10:29:03  fijyrrose ()
# Ensimmainen versio
#
#
# Revision 1.2  2016/12/08 09:46:10  fijyrrose ()
# - lisatty arkistohakemiston luonti ellei sita jo ole 
#
##
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_wal_arc_to_dir.sh

# Load common environment variables
. /home/fujitsu/conf/fuji_pg_common.sh

FILEWITHPATH=$PGDATA/$1
FILE=$2

if [ ! -e "$WALL_ARC_DIR" ]                # Check and create archive Directory.
then
    mkdir -p "$WALL_ARC_DIR"  1>$TMPFILE 2>&1
fi

if [ ! -w "$WALL_ARC_DIR" ]                # Check archive directory exists.
then
    if chk_if_print_message "CRITICAL"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_wall_arc_to_dir_errors.out
        echo "CRITICAL PG_LOG_ARCHIVING alert -  Archive Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    rm -rf $TMPFILE
    exit '-1'
fi

# Seuraava valinta ohjaa skippaamaan koko WAL lokien kopioinnin
# -> arkistointia ei siis tehda, mutta palautetaan kuitenkin ok koodi
#    niin etta WAL lokien kierratys toimii normaalisti
if [ "$DONOTDOARCHIVING" = "Y" ]
then
  # echo "fuji_pg_wal_arc_to_dir.sh: Arkistointi valittu skipattavaksi, ei siis tehda WAL lokien kopiointia" >&2 
  exit 0
fi

# Seuraava valinta ohjaa keskeyttamaan  WAL lokien kopioinnin
# -> arkistointia ei siis tehda, mutta palautetaan error koodi
#    niin etta WAL lokien kierratys keskeytyy ja lokeja kertyy
#    koko ajan lisaa 
if [ "$CANCELWALARCHIVING" = "Y" ]
then
  echo "fuji_pg_wal_arc_to_dir.sh: Archiving canceled - don't use long - generate lot of WAL logs " >&2 
  exit 1
fi

# Seuraava valinta ohjaa etta WAL lokit arkistoidaan ainoastaan
# online backupin ajalta.
# Muina aikoina rutiini ainoastaan palauttaa ok-koodin eika
# varsinaista Wal lokin arkistointia tehda.
if [ "$ONLYCOPYDURINGBACKUP" = "Y" ]
then
  if [ -f $BACKUP_FLAG_FILE ]
  then
    echo "fuji_pg_wal_arc_to_dir.sh: Online backup running, copying: $FILEWITHPATH" >&2
  else 
    exit 0
  fi
fi 
# Jos arkistojen  backup on menossa ja valinta ettei kopioida
# sen aikana paalla keskeytetaan
# (palautetaan false ettei WAL lokeja poisteta ennen aikojaan)
if [ "$BREAKCOPYDURINGARCBACKUP" = "Y" ] && [ -f $ARC_BACKUP_FLAG_FILE ]
then
  echo "fuji_pg_wal_arc_to_dir.sh: WAL archive backup running, copying is not done: $FILEWITHPATH" >&2
  exit 1
fi 
# Tutkitaan ettei tiedosto ole jo arkistoituna
# (voi tulla eteen jos usealta palvelimelta arkistoidaan samaan paikkaan)
# Tutkitaan lisaksi etta tiedosto on tasmalleen samanlainen,
# joissain tilanteissa (esim. arkistot eri filesystemilla ja
# filesystem tayttyy = syntyy nolla kokoisia tiedostoja)
# arkistotiedostot saattavat syntya virheellisina.
# if [ -f "$WALL_ARC_DIR/$2" ]
cmp --silent $FILEWITHPATH $WALL_ARC_DIR/$2
if [ $? = 0 ]
then
   echo "fuji_pg_wal_arc_to_dir.sh: $WALL_ARC_DIR/$2 already archived" >&2
  exit 0
fi
# echo "fuji_pg_wal_arc_to_dir.sh: $FILEWITHPATH : $FILE" >&2
cp -f $FILEWITHPATH $WALL_ARC_DIR/$2 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    # cat $TMPFILE >&2
    if chk_if_print_message "CRITICAL"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_wall_arc_to_dir_errors.out
        echo "CRITICAL PG_LOG_ARCHIVING alert - problems with wal log archiving" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
    rm -rf $TMPFILE
    exit '-1'
fi

# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
 
