#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_wal_archive_backup.sh,v $
##      $Revision: 1.6 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL klusterista online varmistukset
##
##      $Author: rosenjyr $
##      $Date: 2019/06/12 10:15:30 $
##
##      $Log: fuji_pg_wal_archive_backup.sh,v $
#
# Revision 1.1  2015/05/04 10:27:03  fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2015/12/21 15:52:10  fijyrrose ()
# Muutettu tapaa jolla valitaan varmistettavat ja poistettavat arkistot.
# Nain valtetaan tilanne jossa kopioitavaan arkistoon tulisi kirjoituksia.
#
# Revision 1.3  2016/02/01 09:01:05  fijyrrose ()
# Muutettu varmistushakemiston olemassaolotarkistusta: 
# ei koiteta luoda vaan keskeytetaan
#
# Revision 1.4  2016/12/08 09:52:05  fijyrrose ()
# - lisatty varmistushakemiston luonti ellei sita jo ole
# - muutettu WAL arkistojen talletus tar-pakettiin niin etta
#   lisataan tiedoston loppuun loopissa
#   (muuten voi tar komentorivi tulla liian pitkaksi)
# - muutettu poistettavien WAL arkistojen haku
#
# Revision 1.5  2017/05/11 12:39:25  fijyrrose ()
# Muutettu arkistolokien varmistusta tar loop/append:sta -> tar -T list
#
# Revision 1.6  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
##
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_wal_archive_backup.sh
#
# Debug
# export VFY_ALL=1


# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

VERSION=$($PG_CTL -V | awk -F' ' '{print($3)}')
HOST=`hostname -s`
DATE=$(date "+%Y%m%d")
TIMESTAMP=$(date "+%Y.%m.%d %T")

touch $LOGFILE
fuji_subalku >> $LOGFILE

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - can not get database information" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

# Tutkitaan onko kanta standby roolissa jolloin ei ajeta tata
if chk_if_pg_is_in_recovery
then
  echo "PostgreSQL is in recovery. Exiting." >> $LOGFILE
  fuji_subloppu >> $LOGFILE
  rm_old_flag_files
  exit 0
fi

if [ ! -z "$REMOTESERVERTOMOVE" -a ! -z "$ONLINE_BACKUP_DIR" ]
then
    echo "Defined variable REMOTESERVERTOMOVE: $REMOTESERVERTOMOVE as well as ONLINE_BACKUP_DIR: $ONLINE_BACKUP_DIR" > $TMPFILE
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_wal_archive_backup_errors.out
        echo "MAJOR PG_WAL_ARCHIVE_BACKUP alert - can't find  backup directory" variables | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

if [ ! -e "$ONLINE_BACKUP_DIR" ]                # Check and create Backup Directory.
then
    mkdir -p "$ONLINE_BACKUP_DIR"
fi

if [ ! -w "$ONLINE_BACKUP_DIR" ]                # Check Backup Directory exists.
then
    if chk_if_print_message "MAJOR"
    then
        echo "Backup Directory $ONLINE_BACKUP_DIR does not exists" >> $LOGFILE
        echo "MAJOR PG_DUMP_BACKUP alert - Online backup Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

if [ -f $BACKUP_FLAG_FILE -o -f $ARC_BACKUP_FLAG_FILE ]
then
    echo "Lipputiedostot oli jo valmiiksi - online/archive backup menossa (keskeytetaan tama)" >> $LOGFILE
    exit 0
fi

echo "$TIMESTAMP" > $ARC_BACKUP_FLAG_FILE
$PGHOME/bin/psql --tuples-only --command "select pg_switch_xlog();" 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_wal_archive_backup_errors.out
        echo "MAJOR PG_WAL_ARCHIVE_BACKUP alert - error in pg_switch_xlog" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    rm -f $ARC_BACKUP_FLAG_FILE
    exit '-1'
else
  my_tmp_var=$(cat $TMPFILE)
  rm -rf $TMPFILE
fi

# Haetaan pg_archivecleanup:a varten viimeinen sailytettava
BACKUP_ARC=$(ls -t $WALL_ARC_DIR | head -1)

WALTARFILELISTTMP=$WORKING_DIR/tmp/onlinebackup_wal_archive_list.tmp

STARTWALLLOCATION=$(echo $my_tmp_var  | sed -e 's/[^a-zA-Z0-9]/_/g')
# Odotetaan viela hetki niin etta kaikki WAL data on varmasti arkistoitu
sleep 5

# echo "$TIMESTAMP" > $ARC_BACKUP_FLAG_FILE
if [ -z $REMOTESERVERTOMOVE ]
then
  WALTARFILE="$ONLINE_BACKUP_DIR/$HOST-$VERSION-$STARTWALLLOCATION-wal_arcs-only-$DATE.tar.gz"
  find $WALL_ARC_DIR -type f ! -newer $WALL_ARC_DIR/$BACKUP_ARC > $WALTARFILELISTTMP
  tar -T $WALTARFILELISTTMP -czf "$WALTARFILE" 1>$TMPFILE 2>&1
  ret=$?
else
  WALTARFILE="$REMOTEDIR/$HOST-$VERSION-$STARTWALLLOCATION-wal_arcs-only-$DATE.tar.gz"
#   tar czf - "$WALL_ARC_DIR"  | ssh $REMOTESERVERTOMOVE "cat > $WALTARFILE" 1>$TMPFILE 2>&1
  tar czf - `find $WALL_ARC_DIR -type f ! -newer $WALL_ARC_DIR/$BACKUP_ARC`  | ssh $REMOTESERVERTOMOVE "cat > $WALTARFILE" 1>$TMPFILE 2>&1
  ret=$?
fi

# echo "tar chzf wal archive, paluukoodi: $ret"
if [ $ret -gt 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_wal_archive_backup_errors.out
        echo "MAJOR PG_WAL_ARCHIVE_BACKUP alert - error in archive tar" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    rm -f $ARC_BACKUP_FLAG_FILE
    exit '-1'
fi

rm -f $ARC_BACKUP_FLAG_FILE

echo -e "Otettu tar varmistus WAL arkistoista\nTarripallo: " >> $LOGFILE
if [ -z $REMOTESERVERTOMOVE ]
then
  ls -l "$WALTARFILE"  >> $LOGFILE
else
  ssh $REMOTESERVERTOMOVE "ls -l $WALTARFILE" >> $LOGFILE
fi


if [ ! -z $REMOTESERVERTOCOPY ]
then
  echo -e "Kopioidaan tiedostot \n$WALTARFILE \netapalvelimelle: $REMOTESERVERTOCOPY" >> $LOGFILE
  scp -p $WALTARFILE ${REMOTESERVERTOCOPY}:${REMOTEDIR}/. 1>/dev/null 2>&1
# TODO: naihin tarkistukset
fi

rm -f $ARC_BACKUP_FLAG_FILE
# Poistetaan jo varmistetut arkistot:
# BACKUP_ARC=$(ls -t $WALL_ARC_DIR | head -1)
echo -e "\nPoistetaan varmistusajankohtaa vanhemmat WAL arkistot\neli vanhin sailytettava:" >> $LOGFILE
ls -l $WALL_ARC_DIR/$BACKUP_ARC >> $LOGFILE
echo " " >> $LOGFILE
echo "Poistetaan vanhat arkistot:" >> $LOGFILE
# $PG_ARCHIVECLEANUP -d "$WALL_ARC_DIR" "$BACKUP_ARC" 1>>$LOGFILE 2>&1
/home/fujitsu/bin/my_pg_archivecleanup.sh "$WALL_ARC_DIR" "$BACKUP_ARC" 1>>$LOGFILE 2>&1
# TODO: lisaa virhetarkistus


fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
