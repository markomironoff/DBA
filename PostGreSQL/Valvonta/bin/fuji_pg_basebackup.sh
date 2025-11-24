#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2017 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_basebackup.sh,v $
##      $Revision: 1.3 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL klusterista online varmistukset
##                pg_basebackup:lla
##
##      $Author: rosenjyr $
##      $Date:  2019/10/02 15:10:40 $
##
##      $Log: fuji_pg_basebackup.sh,v $
#
# Revision 1.0   2017/01/17 16:37:10 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2017/05/11 12:39:25  fijyrrose ()
# Muutettu arkistolokien varmistusta tar loop/append:sta -> tar -T list
# Lisatty vanhojen *.backup statustiedostojen poisto
#
# Revision 1.2  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
# Revision 1.3  2019/10/02 15:10:40  fijyrrose ()
# Muutettu example tiedostoon pg_xlog -> pg_wal

##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_basebackup.sh
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
fuji_subalku > $LOGFILE

# Poistetaan vanhat lokit (muuta tahan lokien sailytysaika)
LOGDIR=$(dirname $LOGFILE)
find $LOGDIR -name "*.log" -type f -mtime +${BACKUPLOGRETENTIONTIME} -exec rm -f {} \;

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

LABEL="$ONLINE_BACKUP_DIR/$HOST-$VERSION-basebackup-$DATE"

if [ ! -e "$ONLINE_BACKUP_DIR" ]                # Check and create Backup Directory.
then
    mkdir -p "$ONLINE_BACKUP_DIR"
else
# Seuraava ainoastaa jos halutaan sailyttaa edellinen varmistus levylla
# siihen asti kun nykyinen on valmistunut (vaatii 2x tilat)
    if [ $BASEBACKUPSKEPTONDISK -eq -1 ]
    then
      rm -rf $ONLINE_BACKUP_DIR/*
    else
      mv $ONLINE_BACKUP_DIR ${ONLINE_BACKUP_DIR}_prev
      mkdir -p "$ONLINE_BACKUP_DIR"
    fi
fi

if [ ! -w "$ONLINE_BACKUP_DIR" ]                # Check Backup Directory exists.
then
    if chk_if_print_message "MAJOR"
    then
        echo "Backup Directory $ONLINE_BACKUP_DIR does not exists" >> $LOGFILE
        echo "MAJOR PG_ONLINE_BACKUP alert - Online backup Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

if [ -f $ARC_BACKUP_FLAG_FILE ]
then
    echo "Lipputiedostot oli jo valmiiksi, edellinen wal-arkistojen backup menossa, tai keskeytynyt epanormaalisti" >> $LOGFILE
    echo "Tarkista ja/tai poista tiedosto: $ARC_BACKUP_FLAG_FILE" >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - wal-archive backup already running or previous interrupted abnormally ($ARC_BACKUP_FLAG_FILE)" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

# Varmistushakemiston pitaa olla tyhja
# rm -rf $ONLINE_BACKUP_DIR/*

if [ -z "$PG_BASEBACKUP_CMD" ]
then
# Otetaan tar pakettina jotta saadaan myos mahdolliset tablespaces
# versiossa 9.3 ei ole mahdollista tablespace-mappingia joten tama on
# ainoa keino saada tablespacet mukaan
$PG_BASEBACKUP -X f -D $ONLINE_BACKUP_DIR -Ft 1>$TMPFILE 2>&1
ret=$?
else
$PG_BASEBACKUP_CMD 1>$TMPFILE 2>&1
ret=$?
fi
# echo "pg_basebackup paluukoodi: $ret"
if [ $ret -ne 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - error in database pg_basebackup" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi
echo -e "Otettu pg_basebackup varmistus $PGDATA hakemistosta\nTarripallot: " >> $LOGFILE
ls -l "$ONLINE_BACKUP_DIR"  >> $LOGFILE

# Otetaan viela arkistot talteen 
# Optionaalinen, oletuksena pg_basebackup kopioi pg_wal sisallon
if [ "$BASEBACKUP_DO_ARCHIVE_BACKUP" = "Y" ]
then
# Odotetaan viela hetki niin etta kaikki WAL data on varmasti arkistoitu
sleep 10

WALTARFILELISTTMP=$WORKING_DIR/tmp/basebackup_wal_archive_list.tmp
BACKUP_ARC=$(ls -t $WALL_ARC_DIR | head -1)
echo "$TIMESTAMP" > $ARC_BACKUP_FLAG_FILE
WALTARFILE="$ONLINE_BACKUP_DIR/$HOST-$VERSION-$STARTWALLLOCATION-wal_arcs-$DATE.tar.gz"
find $WALL_ARC_DIR -type f ! -newer $WALL_ARC_DIR/$BACKUP_ARC > $WALTARFILELISTTMP
tar -T $WALTARFILELISTTMP -czf "$WALTARFILE" 1>$TMPFILE 2>&1
ret=$?

# echo "tar rf wal archive, paluukoodi: $ret"
if [ $ret -gt 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - error in archive tar" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    rm -f $ARC_BACKUP_FLAG_FILE
    exit '-1'
fi

rm -f $ARC_BACKUP_FLAG_FILE

echo -e "Otettu tar varmistus WAL arkistoista\nTarripallo: " >> $LOGFILE
ls -l "$WALTARFILE"  >> $LOGFILE
fi # end if BASEBACKUP_DO_ARCHIVE_BACKUP

# Poistetaan vanhat arkistot
DEL_ARC=$(ls -ltr $WALL_ARC_DIR | grep ".backup" | tail -1 | awk '{print($9)}') 
echo -e "\nBackup archive info:" >> $LOGFILE
cat $WALL_ARC_DIR/$DEL_ARC >> $LOGFILE
echo -e "\nPoistetaan varmistusajankohtaa vanhemmat WAL arkistot\neli vanhin sailytettava:" >> $LOGFILE
ls -l $WALL_ARC_DIR/$DEL_ARC >> $LOGFILE
echo " " >> $LOGFILE
echo "Poistetaan vanhat arkistot:" >> $LOGFILE
# echo "$PG_ARCHIVECLEANUP \"$WALL_ARC_DIR\" \"$DEL_ARC\"" 
$PG_ARCHIVECLEANUP -d "$WALL_ARC_DIR" "$DEL_ARC" 1>>$LOGFILE 2>&1
# TODO: lisaa virhetarkistus

echo "Poistetaan vanhat (>2kk) .backup tiedostot" >> $LOGFILE
find $WALL_ARC_DIR -name "*.backup" -type f -mtime +60 -exec ls -l {} \;
find $WALL_ARC_DIR -name "*.backup" -type f -mtime +60 -exec rm -f {} \;

# Poistetaan edellinen varmistus
if [ -d "${ONLINE_BACKUP_DIR}_prev" ]
then
  rm -rf ${ONLINE_BACKUP_DIR}_prev
fi
# Palautusta varten mallitiedosto
RESTORE_EXAMPLE=$LABEL.how_to_restore.example
echo "Palautuksen mallitiedosto: $RESTORE_EXAMPLE" >> $LOGFILE
#
# Tehdaan malli ko. varmistuksen palautuksesta
echo -e "
# Mallia varmistukselta palauttamiseksi\n\
# katso vastaavan paivan varmistusloki\n\
cat $LOGFILE\n\n\
# Ota ensin  instanssi alas (ellei sitten ole jo vikatilanteen seurauksena):
pg_ctl stop -m fast\n\n\
# Jos levytilaa riittaa ota talteen koko data hakemisto, esim\n\
mv $PGDATA $PGDATA.old\n\
# Tai minimissaan ota pg_wal hakemiston sisalto jonnekin talteen ja tyhjaa sitten hakemisto, esim.\n\
# mkdir -p $ONLINE_BACKUP_DIR/tmp/pg_wal\n\
# mv $PGDATA/pg_wal/* $ONLINE_BACKUP_DIR/tmp/pg_wal/.\n  
# ja poista alkuperainen data:\n# rm -rf $PGDATA/*\n\n  
# Luo/tarkista etta taulualuehakemistot on olemassa:" > $TMPFILE

$PGHOME/psql \
    -X \
    -c "\db" \
    --single-transaction \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    --no-align \
    -t \
    --field-separator ' ' \
    --quiet \
| while read name owner location ; do
    # echo "TABLESPACE: $name $owner $location"
    if [ ! -z $location ]
    then
      # For restore file
      echo "mkdir -p $location" >> $TMPFILE
      PG_dir=$(ls $location)
      # echo "location/PG_DIR: $location/$PG_dir"
      ls $location/$PG_dir | while read subdirectory ; do
        echo "mkdir -p $location/$PG_dir/$subdirectory" >> $TMPFILE
      done
    fi
done

echo -e "
# Tar varmistukselta palautus - data:t $PGDATA hakemistoon:\n\
cd $PGDATA" >> $TMPFILE
echo "tar xf \"$ONLINE_BACKUP_DIR/base.tar\"" >> $TMPFILE
echo -e "
# Palautetaan mahdolliset taulualueet:"  >> $TMPFILE
for tbl_link_name in $(ls $PGDATA/pg_tblspc)
do
  echo "cd $PGDATA/pg_tblspc/$tbl_link_name" >> $TMPFILE
  echo "tar xf \"$ONLINE_BACKUP_DIR/$tbl_link_name.tar\"" >> $TMPFILE
  echo " " >> $TMPFILE  
done

echo -e "
# Seka Luo/tarkista etta(esim. pg_wal) linkit on olemassa:" >> $TMPFILE
find $PGDATA -type l -ls | grep -v "pg_tblspc" | awk '{printf "ln -s %s %s\n", $13, $11}' >> $TMPFILE

if [ "$BASEBACKUP_DO_ARCHIVE_BACKUP" = "Y" ]
then
echo -e "
# WAL arkistojen palautus Tar varmistukselta - $WALL_ARC_DIR hakemistoon:\n\
# HUOM! Saattaa olla etta base backupilta palautus riittaa - siis jos wal_keep_segments on ollut riittava\n\
# Jos lokien arkistointi on ollut paalla ja arkistovarmistus loytyy, kannattaa aina palauttaa tamakin\n\
cd /" >> $TMPFILE
echo "tar xhzf \"$WALTARFILE\"" >> $TMPFILE
fi # end if BASEBACKUP_DO_ARCHIVE_BACKUP

echo -e "
# Tarvittaessa kopioi viimeiset WAL lokit takaisin:\n\
# cp -pR $PGDATA.old/pg_wal/* $PGDATA/pg_wal/.\n
# tai: cp -pR $ONLINE_BACKUP_DIR/tmp/pg_wal_orig/* $PGDATA/pg_wal/.\n\n 
# Jos haluat tehda PITR palautuksen arkistoja kayttaen\n\
# HUOM! WAL-arkistojen loydyttava $WALL_ARC_DIR hakemistosta\n\
# Luo tiedosto recoverya varten\n\
# (seuraava riippuu siita milla komennolla arkistot on tehty)\n\
# echo \"restore_command = 'cp $WALL_ARC_DIR/%f %p'\" > $PGDATA/recovery.conf\n\
# ja kaynnista tietokanta, seka seuraa tilannetta lokilta\n\
pg_ctl start\n\
# ls -ltr $PGDATA/pg_log\n\
# tail -f $PGDATA/pg_log/<jokuloki>.log\n\
" >>$TMPFILE

cat $TMPFILE >>$RESTORE_EXAMPLE

fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
