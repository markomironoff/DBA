#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2015 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_online_backup.sh,v $
##      $Revision: 1.9 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL klusterista online varmistukset
##
##      $Author: rosenjyr $
##      $Date: 2019/10/02 15:10:40 $
##
##      $Log: fuji_pg_online_backup.sh,v $
#
# Revision 1.1  2015/05/04 10:26:03  fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2015/06/02 07:56:15  fijyrrose ()
# Muutettu pg_ctl komento muuttujaksi PG_CTL jossa komento polkuineen
#
# Revision 1.3  2015/12/29 10:43:20  fijyrrose ()
# Muutettu tapaa jolla valitaan varmistettavat ja poistettavat arkistot.
# Nain valtetaan tilanne jossa kopioitavaan arkistoon tulisi kirjoituksia.
# Lisaksi poistetaan mahdolliset online varmistusten valilla syntyneet
# wal-arkistojen varmistukset
#
# Revision 1.4  2016/02/01 08:41:10  fijyrrose ()
# Muutettu varmistushakemiston olemassaolotarkistusta: 
# ei koiteta luoda vaan keskeytetaan
#
# Revision 1.5  2016/12/08 09:38:05  fijyrrose ()
# - lisatty varmistushakemiston luonti ellei sita jo ole
# - muutettu WAL arkistojen talletus tar-pakettiin niin etta
#   lisataan tiedoston loppuun loopissa
#   (muuten voi tar komentorivi tulla liian pitkaksi)
# - muutettu varmistettavien WAL arkistojen haku
#   -- haetaan kaikki, eika ainoastaan .backup tiedostoon asti
#      (jossain tilanteessa saattoi vastaava arkisto tulla .backup
#       tiedoston luonnin jalkeen)
#
# Revision 1.6  2017/01/17 16:35:15  fijyrrose ()
# Mahdollisuus tyhjata varmistushakemisto ennen kuin ajetaan uusi varmistus 
#
# Revision 1.7  2017/05/11 12:39:25  fijyrrose ()
# Muutettu arkistolokien varmistusta tar loop/append:sta -> tar -T list
# Lisatty vanhojen *.backup statustiedostojen poisto
#
# Revision 1.8  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
# Revision 1.9  2019/10/02 15:10:40  fijyrrose ()
# Muutettu example tiedostoon pg_xlog -> pg_wal
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_online_backup.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

VERSION=$($PG_CTL -V | awk -F' ' '{print($3)}')
HOST=`hostname -s`
DATE=$(date "+%Y%m%d")
TIMESTAMP=$(date "+%Y.%m.%d %T")

LABEL="$ONLINE_BACKUP_DIR/$HOST-$VERSION-online-$DATE"

touch $LOGFILE
fuji_subalku > $LOGFILE

# Poistetaan vanhat lokit (muuta tahan lokien sailytysaika)
LOGDIR=$(dirname $LOGFILE)
find $LOGDIR -name "*.log" -type f -mtime +${BACKUPLOGRETENTIONTIME} -exec rm -f {} \;
if [ ! -z "$REMOTESERVERTOMOVE" -a ! -z "$ONLINE_BACKUP_DIR" ]
then
    echo "Defined variable REMOTESERVERTOMOVE: $REMOTESERVERTOMOVE as well as ONLINE_BACKUP_DIR: $ONLINE_BACKUP_DIR" > $TMPFILE
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - error in main variables" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

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
  exit 0
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
        echo "MAJOR PG_ONLINE_BACKUP alert - Online backup Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

if [ -f $BACKUP_FLAG_FILE -o -f $ARC_BACKUP_FLAG_FILE ]
then
    echo "Lipputiedostot oli jo valmiiksi, edellinen backup menossa, tai keskeytynyt epanormaalisti" >> $LOGFILE
    echo "Tarkista ja/tai poista tiedosto: $BACKUP_FLAG_FILE $ARC_BACKUP_FLAG_FILE" >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - backup already running or previous interrupted abnormally ($BACKUP_FLAG_FILE $ARC_BACKUP_FLAG_FILEo" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

if [ $BACKUPSKEPTONDISK -eq -1 ]
then
  echo "Tyhjennetaan varmistushakemisto $ONLINE_BACKUP_DIR"
  rm -rf $ONLINE_BACKUP_DIR/*
  unset BACKUPSKEPTONDISK
fi

echo "$TIMESTAMP" > $BACKUP_FLAG_FILE
# trap "psql -q --command 'SELECT pg_stop_backup();'" exit
$PGHOME/bin/psql --tuples-only --command "SELECT pg_start_backup('$LABEL');" 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - error in pg_start_backup" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    rm -f $BACKUP_FLAG_FILE
    psql -q --command 'SELECT pg_stop_backup();'
    exit '-1'
else
  my_tmp_var=$(cat $TMPFILE)
  rm -rf $TMPFILE
fi

echo $?

# echo "$TIMESTAMP" > $BACKUP_FLAG_FILE
STARTWALLLOCATION=$(echo $my_tmp_var  | sed -e 's/[^a-zA-Z0-9]/_/g')
if [ -z $REMOTESERVERTOMOVE ]
then
  TARFILE="$ONLINE_BACKUP_DIR/$HOST-$VERSION-$STARTWALLLOCATION-online-$DATE.tar.gz"
  RESTORE_EXAMPLE=$ONLINE_BACKUP_DIR/$HOST-$VERSION-$STARTWALLLOCATION-$DATE.how_to_restore.example
else
  TARFILE="$REMOTEDIR/$HOST-$VERSION-$STARTWALLLOCATION-online-$DATE.tar.gz"
  RESTORE_EXAMPLE=$REMOTEDIR/$HOST-$VERSION-$STARTWALLLOCATION-$DATE.how_to_restore.example
fi

# Tar seuraa -h valinnalla sym linkin takana olevat tiedostot
# HUOM! Linkit on luotava valmiiksi ennen palautusta
locret=0
remret=0
if [ -z $REMOTESERVERTOMOVE ]
then
  tar chzf "$TARFILE" --exclude "$PGDATA/pg_wal" "$PGDATA" 1>$TMPFILE 2>&1
  locret=$?
else
  tar chzf - "$PGDATA" --exclude "$PGDATA/pg_wal"  | ssh $REMOTESERVERTOMOVE "cat > $TARFILE" 1>$TMPFILE 2>&1
  remret=$?
fi
ret=$?
# echo "tar chzf datat, paluukoodi: $ret"
if [ $locret -eq 1 ]
then
  cat $TMPFILE >> $LOGFILE
  echo "Muutoksia varmistuksenaikaisiin kantatiedostoihin - ei haittaa koska pg_start_backup annettu" >> $LOGFILE
fi
if [ $locret -gt 1 -o $remret -ne 0 ]
then
    cat $TMPFILE >> $LOGFILE
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
        echo "MAJOR PG_ONLINE_BACKUP alert - error in database tar" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    $PGHOME/bin/psql -q --command 'SELECT pg_stop_backup();'
    rm -f $BACKUP_FLAG_FILE
    exit '-1'
fi
echo -e "Otettu tar varmistus $PGDATA hakemistosta\nTarripallo: " >> $LOGFILE

if [ -z $REMOTESERVERTOMOVE ]
then
  ls -l "$TARFILE"  >> $LOGFILE
else
  ssh $REMOTESERVERTOMOVE "ls -l $TARFILE" >> $LOGFILE
fi

$PGHOME/bin/psql -q --command 'SELECT pg_stop_backup();'
rm -f $BACKUP_FLAG_FILE

# Odotetaan viela hetki niin etta kaikki WAL data on varmasti arkistoitu
sleep 10

#
WALTARFILELISTTMP=$WORKING_DIR/tmp/onlinebackup_wal_archive_list.tmp 
BACKUP_ARC=$(ls -t $WALL_ARC_DIR | head -1)
echo "$TIMESTAMP" > $ARC_BACKUP_FLAG_FILE
if [ -z $REMOTESERVERTOMOVE ]
then
  WALTARFILE="$ONLINE_BACKUP_DIR/$HOST-$VERSION-$STARTWALLLOCATION-wal_arcs-$DATE.tar.gz"
  find $WALL_ARC_DIR -type f ! -newer $WALL_ARC_DIR/$BACKUP_ARC > $WALTARFILELISTTMP
  tar -T $WALTARFILELISTTMP -czf "$WALTARFILE" 1>$TMPFILE 2>&1
  ret=$?
else
  WALTARFILE="$REMOTEDIR/$HOST-$VERSION-$STARTWALLLOCATION-wal_arcs-$DATE.tar.gz"
  tar czf - `find $WALL_ARC_DIR -type f ! -newer $WALL_ARC_DIR/$BACKUP_ARC`  | ssh $REMOTESERVERTOMOVE "cat > $WALTARFILE" 1>$TMPFILE 2>&1
  ret=$?
  echo "tehtiin wal remote tar/ssh"
  cat $TMPFILE
fi

# echo "tar chzf wal archive, paluukoodi: $ret"
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
if [ -z $REMOTESERVERTOMOVE ]
then
  ls -l "$WALTARFILE"  >> $LOGFILE
else
  ssh $REMOTESERVERTOMOVE "ls -l $WALTARFILE" >> $LOGFILE
fi

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

if [ -z $REMOTESERVERTOMOVE ]
then
  echo "Palautuksen mallitiedosto: $RESTORE_EXAMPLE" >> $LOGFILE
else
  echo "Palautuksen mallitiedosto: $REMOTESERVERTOMOVE:$RESTORE_EXAMPLE" >> $LOGFILE
fi
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
# Tai minimissaan ota pg_wal hakemiston sisalto jonnekin talteen, esim.\n\
# mkdir -p $ONLINE_BACKUP_DIR/tmp/pg_wal\n\
# mv $PGDATA/pg_wal/* $ONLINE_BACKUP_DIR/tmp/pg_wal/.\n  
# ja poista alkuperainen data: rm -rf $PGDATA/*\n\n  
# Luo/tarkista etta taulualuehakemistot on olemassa:" > $TMPFILE

$PGHOME/bin/psql \
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
      ls $location/$PG_dir | while read subdirectory ; do
        echo "mkdir -p $location/$PG_dir/$subdirectory" >> $TMPFILE
      done
    fi
done

echo -e "
# Seka Luo/tarkista etta taulualuelinkit on olemassa:\n\
mkdir -p $PGDATA/pg_tblspc" >> $TMPFILE
find $PGDATA -type l -ls | awk '{printf "ln -s %s %s\n", $13, $11}' >> $TMPFILE

echo -e "
# Tar varmistukselta palautus - data:t $PGDATA hakemistoon:\n\
cd /" >> $TMPFILE
if [ -z $REMOTESERVERTOMOVE ]
then
  echo "tar xhzf \"$TARFILE\"" >> $TMPFILE
else
  echo "ssh $REMOTESERVERTOMOVE \"cat $TARFILE\" | tar xhzf -" >> $TMPFILE
fi
echo -e "
# Poista varmistukselta tullut varmistuksenaikainen lipputiedosto\n\
# (HUOM! ellei tata poisteta ei seuraava varmistus toimi)\n\
rm -f $BACKUP_FLAG_FILE\n 
# Seka poista varmistukselta tulleet postmaster.pid ja postmaster.opts tiedostot\n\
rm -f $PGDATA/postmaster.pid\n 
rm -f $PGDATA/postmaster.opts\n 
# Tar varmistukselta palautus - WAL:t $WALL_ARC_DIR hakemistoon:\n\
# (tassa on varmistuksen aikana syntyneet WAL arkistot)\n\
cd /" >> $TMPFILE
if [ -z $REMOTESERVERTOMOVE ]
then
  echo "tar xhzf \"$WALTARFILE\"" >> $TMPFILE
else
  echo "ssh $REMOTESERVERTOMOVE \"cat $WALTARFILE\" | tar xhzf -" >> $TMPFILE
fi
echo -e "
# Luo pg_wal hakemisto tyhjana\n\
mkdir -p \"$PGDATA/pg_wal\"\n\
# Ja tarvittaessa kopioi viimeiset WAL lokit takaisin palautettujen tilalle:\n 
cp -pR $PGDATA.old/pg_wal/* $PGDATA/pg_wal/.\n
# tai: cp -pR $ONLINE_BACKUP_DIR/tmp/pg_wal_orig/* $PGDATA/pg_wal/.\n\n 
# Luo tiedosto recoverya varten\n\
# (seuraava riippuu siita milla komennolla arkistot on tehty)\n\
echo \"restore_command = 'cp $WALL_ARC_DIR/%f %p'\" > $PGDATA/recovery.conf\n\
# ja kaynnista tietokanta, seka seuraa tilannetta lokilta\n\
pg_ctl start\n\
# ls -ltr $PGDATA/pg_log\n\
# tail -f $PGDATA/pg_log/<jokuloki>.log\n\
# ja poista recovery:ssa kaytettyt wal-arkistot, esim\n\
# $PGHOME/bin/pg_archivecleanup -d $WALL_ARC_DIR/ <viimeksi palautettu archive log> (Loydat sen esim. ls -ltr $WALL_ARC_DIR)\n\
" >>$TMPFILE

if [ -z $REMOTESERVERTOMOVE ]
then
  cat $TMPFILE >>$RESTORE_EXAMPLE
else
  scp $TMPFILE $REMOTESERVERTOMOVE:$RESTORE_EXAMPLE 1>/dev/null 2>&1
fi


bWalToRemote=false
lRemoteServer==
if [ ! -z $REMOTESERVERTOMOVE ]
then
  lRemoteServer=$REMOTESERVERTOMOVE
  bWalToRemote=true
fi
if [ ! -z $REMOTESERVERTOCOPY ]
then
  bWalToRemote=true
  lRemoteServer=$REMOTESERVERTOCOPY
  echo -e "Kopioidaan tiedostot \n$TARFILE  \n$WALTARFILE \n$RESTORE_EXAMPLE \netapalvelimelle: $REMOTESERVERTOCOPY" >> $LOGFILE
  scp -p $TARFILE ${REMOTESERVERTOCOPY}:${REMOTEDIR}/. 1>/dev/null 2>&1
  scp -p $WALTARFILE ${REMOTESERVERTOCOPY}:${REMOTEDIR}/. 1>/dev/null 2>&1
  scp -p $RESTORE_EXAMPLE ${REMOTESERVERTOCOPY}:${REMOTEDIR}/. 1>/dev/null 2>&1
# TODO: naihin tarkistukset
fi

if [ ! -z $BACKUPSKEPTONDISK ]
then
  # Local levya ei koitetakkaan siivota jos tehty suoraan remote servelin levylle
  if [ -z $REMOTESERVERTOMOVE ]
  then
  # file_to_comp=$(ls -ltd $ONLINE_BACKUP_DIR/*online* 2>/dev/null | head -n $BACKUPSKEPTONDISK | tail -1 | awk '{print $9}')
  # if [ ! -z $file_to_comp ]
  # then
    # Seuraavat voisi ottaa kayttoon jos halutaa vapauttaa varmistuslevylta tilaa
    # HUOM! PITR ei talloin online varmistusten valiseen aikaan onnistu
    ## echo "Poistetaan vanhat wal arkistojen varmistukset:" >> $LOGFILE
    ## find $ONLINE_BACKUP_DIR -name "*wal_arcs-only*" -exec ls -l {} \; >> $LOGFILE
    ## find $ONLINE_BACKUP_DIR -name "*wal_arcs-only*" -exec rm -f {} \; >> $LOGFILE

    echo "Poistetaan vanhat local varmistukset:" >> $LOGFILE
    # find $ONLINE_BACKUP_DIR -type f ! -newer $file_to_comp ! -samefile $file_to_comp -exec ls -l {} \; >> $LOGFILE
    # find $ONLINE_BACKUP_DIR -type f ! -newer $file_to_comp ! -samefile $file_to_comp -exec rm -f {} \; >> $LOGFILE
    find $ONLINE_BACKUP_DIR -type f -mtime +${BACKUPSKEPTONDISK} -exec ls -l {} \; >> $LOGFILE
    find $ONLINE_BACKUP_DIR -type f -mtime +${BACKUPSKEPTONDISK} -exec rm -f {} \; >> $LOGFILE
    if [ $? -gt 0 ]
    then
      cat $TMPFILE >> $LOGFILE
      if chk_if_print_message "MAJOR"
      then
          cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
          echo "MAJOR PG_ONLINE_BACKUP alert - error in find/remove old backups" | \
          ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
          rm -rf $TMPFILE
      fi # end if chk_if...
      exit '-1'
    fi
  # fi
  fi # if REMOTESERVERTOMOVE

  if [ $bWalToRemote = true ]
  then
    # file_to_comp=$(ssh $lRemoteServer "ls -ltd ${REMOTEDIR}/*online* | head -n 2 | tail -1" | awk '{print $9}')
    # if [ ! -z $file_to_comp ]
    #then
      # Seuraavat voisi ottaa kayttoon jos halutaa vapauttaa varmistuslevylta tilaa
      # HUOM! PITR ei talloin online varmistusten valiseen aikaan onnistu
      ## echo "Poistetetaan vanhat wal arkistojen varmistukset:" >> $LOGFILE
      ## ssh $lRemoteServer "find $REMOTEDIR -name \"*wal_arcs-only*\" -exec ls -l {} \;" >> $LOGFILE
      ## ssh $lRemoteServer "find $REMOTEDIR -name \"*wal_arcs-only*\" -exec rm -f {} \;" >> $LOGFILE

      echo "Poistetetaan vanhat remote varmistukset:" >> $LOGFILE
      # ssh $lRemoteServer "find $REMOTEDIR -type f ! -newer $file_to_comp ! -samefile $file_to_comp -exec ls -l {} \;" >> $LOGFILE
      # ssh $lRemoteServer "find $REMOTEDIR -type f ! -newer $file_to_comp ! -samefile $file_to_comp -exec rm -f {} \;" >> $LOGFILE
      ssh $lRemoteServer "find $REMOTEDIR -type f -mtime +${BACKUPSKEPTONDISK} -exec ls -l {} \;" >> $LOGFILE
      ssh $lRemoteServer "find $REMOTEDIR -type f -mtime +${BACKUPSKEPTONDISK} -exec rm -f {} \;" >> $LOGFILE
      if [ $? -gt 0 ]
      then
        cat $TMPFILE >> $LOGFILE
        if chk_if_print_message "MAJOR"
        then
            cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
            echo "MAJOR PG_ONLINE_BACKUP alert - error in find/remove old backups" | \
            ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
            rm -rf $TMPFILE
        fi # end if chk_if...
        exit '-1'
      fi
    # fi # if file_to_comp
  fi # if bWalToRemote
fi # if BACKUPSKEPTONDISK

# if [ ! -z $BACKUPRETENTIONTIME ]
# then
#   echo "Poistetaan $BACKUPRETENTIONTIME vanhemmat varmistukset:" >> $LOGFILE
#   find $ONLINE_BACKUP_DIR -type f -mtime +${BACKUPRETENTIONTIME} -exec ls -l {} \; >> $LOGFILE
#   find $ONLINE_BACKUP_DIR -type f -mtime +${BACKUPRETENTIONTIME} -exec rm -f {} \; 1>$TMPFILE 2>&1
#   if [ $? -gt 0 ]
#   then
#       cat $TMPFILE >> $LOGFILE
#       if chk_if_print_message "MAJOR"
#       then
#           cp $TMPFILE $WORKING_DIR/tmp/pg_online_backup_errors.out
#           echo "MAJOR PG_ONLINE_BACKUP alert - error in find/remove old backups" | \
#          ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
#           rm -rf $TMPFILE
#       fi # end if chk_if...
#       rm -f $ARC_BACKUP_FLAG_FILE
#       exit '-1'
#  fi
# fi

fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0
