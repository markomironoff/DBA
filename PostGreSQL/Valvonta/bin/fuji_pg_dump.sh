#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2012 - 2021
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_dump.sh,v $
##      $Revision: 2.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Ajetaan PostgreSQL kannoista dump-varmistukset
##
##      $Author: rosenjyr $
##      $Date: 2021/04/22 12:23:35 $
##
##      $Log: fuji_pg_dump.sh,v $
##
# Revision 1.1  2015/03/11 11:25:15 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2015/05/04 10:23:05  fijyrrose ()
# Siirretty dump varmistuksiin liittyvat muuttujat fuji_pg_common.sh tiedostoon
#
# Revision 1.3  2015/10/04 09:35:15  fijyrrose ()
# Dump ajetaan custom formaattiin ja annettu mahdollisuus ajaa pelkka metadatan dump
#
# Revision 1.4  2016/01/29 10:14:05  fijyrrose ()
# Tarkistetaan varmistushakemiston olemassaolo ja nostetaan virhe jollei loydy
#
# Revision 1.5  2016/03/11 11:25:15  fijyrrose ()
# Lisatty dumpeille sailytysaika (oletus 30vrk)
#
# Revision 1.6  2016/12/02 07:48:05  fijyrrose ()
# Koitetaan luoda DUMP_DIR hakemisto jollei sita jo ole
#
# Revision 1.7  2017/01/17 14:41:20  fijyrrose ()
# Mahdollisuus tyhjata varmistushakemisto ennen kuin ajetaan uusi dump
#
# Revision 1.8  2017/01/24 14:44:41  fijyrrose ()
# Vanhojen varmistusten poistoa muutettu niin etta poistetaan vaikka varmistuksen
# alku ja loppu olisi eri vuorokausilla
#
# Revision 1.9  2019/06/12 10:15:30  fijyrrose ()
# Lisatty kannan replikoinnin roolin tarkistus -> ei ajeta jos standby
#
# Revision 2.0  2021/04/22 12:23:35  fijyrrose ()
# Lisatty kannan konfiguraatiotietojen varmistus
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_dump.sh
#
# Debug
# export VFY_ALL=1

# Load common postgres routines
. /home/fujitsu/conf/fuji_pg_common.sh

DATE=$(date "+%Y%m%d")

touch $LOGFILE
fuji_subalku > $LOGFILE

# Poistetaan vanhat lokit
LOGDIR=$(dirname $LOGFILE)
find $LOGDIR -name "*.log" -type f -mtime +${BACKUPLOGRETENTIONTIME} -exec rm -f {} \;

$PSQL $PG_CONNECT_OPTS -l -A -F: 1>$TMPFILE 2>&1
if [ $? != 0 ]
then
    if chk_if_print_message "MAJOR"
    then
        cp $TMPFILE $WORKING_DIR/tmp/pg_dump_errors.out
        echo "MAJOR PG_DUMP_BACKUP alert - can not get database information" | \
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

if [ ! -e "$DUMP_DIR" ]                # Check and create Backup Directory.
then
    mkdir -p "$DUMP_DIR"
fi

# Jollei luonti edellisessa onnistunut tulostetaan virheilmoitus
if [ ! -w "$DUMP_DIR" ]                # Check Backup Directory exists.
then
    if chk_if_print_message "MAJOR"
    then
        echo "Backup Directory $DUMP_DIR does not exists" >> $LOGFILE
        echo "MAJOR PG_DUMP_BACKUP alert - Backup Directory does not exists" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        rm -rf $TMPFILE
    fi # end if chk_if...
    exit '-1'
fi

DBS="`cat $TMPFILE | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"
/bin/rm -rf $TMPFILE

# Poistetaan alta kaikki vanhat varmistukset
if [ $DUMPSKEPTONDISK -eq -1 ]
then
  echo "Poistetaan kaikki sisalto hakemistosta $DUMP_DIR" >> $LOGFILE
  rm -rf $DUMP_DIR/*
  unset DUMPSKEPTONDISK
fi

echo "*** Copy all database config files from $PGDATA ***" >> $LOGFILE
pg_confdir="$DUMP_DIR/PG_confs_$DATE"
mkdir -p $pg_confdir 1>/dev/null 2>>$LOGFILE
cp -vp $PGDATA/*.conf $pg_confdir/. 1>>$LOGFILE 2>>$LOGFILE

alldumpfile="$DUMP_DIR/Global_dump_$DATE.sql"
echo "*** pg_dumpall --globals-only ***" >> $LOGFILE
$DUMPALL $PG_CONNECT_OPTS --globals-only -f "$alldumpfile" 1>/dev/null 2>>$LOGFILE
if [ $? != 0 ]
then
    if chk_if_print_message "MAJOR"
    then
        cp $LOGFILE $WORKING_DIR/tmp/pg_dump_errors.out
        echo "MAJOR PG_DUMP_BACKUP alert - errors in pg_dumpall" | \
        ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
        exit '-1'
    fi # end if chk_if...
else
    echo -e "\t*** pg_dumpall: OK ***\n\t$(ls -l $alldumpfile)" >> $LOGFILE

    echo "Remove old dump files, Dir: $DUMP_DIR" >> $LOGFILE
    # remove old dump files
    if [ -z $DUMPSKEPTONDISK ]
    then
      find $DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +30 -exec ls -l {} \; >> $LOGFILE
      find $DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +30 -exec rm -f {} \; >> $LOGFILE
    else
      find $DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec ls -l {} \; >> $LOGFILE
      find $DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec rm -f {} \; >> $LOGFILE
    fi # end if DUMPSKEPTONDISK
fi

for database in $DBS; do
    DB_DUMP_DIR="$DUMP_DIR/$database"
    if [ ! -e "$DB_DUMP_DIR" ]                # Check Backup Directory exists.
    then
        mkdir -p "$DB_DUMP_DIR"
    fi

    DATA=$DB_DUMP_DIR/${database}_metadata_$DATE.sql
    echo "***   pg_dump database metadata: $database ***" >> $LOGFILE
    $PGDUMP $PG_CONNECT_OPTS $DUMP_OPTS_META --file "$DATA" $database  1>/dev/null 2>>$LOGFILE
    if [ $? != 0 ]
    then
        if chk_if_print_message "MAJOR"
        then
            cp $LOGFILE $WORKING_DIR/tmp/pg_dump_errors.out
            echo "MAJOR PG_DUMP_BACKUP alert - errors in pg_dump with database $database" | \
            ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
            exit '-1'
        fi # end if chk_if...
    else
        echo -e "\t***   pg_dump database metadata: \t$database \tOK ***\n\t$(ls -l $DATA)" >> $LOGFILE
    fi

    echo "Remove old metadata sql files, Dir: $DB_DUMP_DIR" >> $LOGFILE
    # remove old dump files
    if [ -z $DUMPSKEPTONDISK ]
    then
      find $DB_DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +30 -exec ls -l {} \; >> $LOGFILE
      find $DB_DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +30 -exec rm -f {} \; >> $LOGFILE
    else
      find $DB_DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec ls -l {} \; >> $LOGFILE
      find $DB_DUMP_DIR/*.sql -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec rm -f {} \; >> $LOGFILE
    fi # end if DUMPSKEPTONDISK

    # Jos halutaan pelkka metadata hypataan loopin loppuun
    if [ "$DUMP_META_ONLY" = "Y" ]
    then
      continue
    fi

    DATA=$DB_DUMP_DIR/${database}_$DATE.dump
    echo "***   pg_dump database: $database ***" >> $LOGFILE
    $PGDUMP $PG_CONNECT_OPTS $DUMP_OPTS --file "$DATA" $database  1>/dev/null 2>>$LOGFILE
    if [ $? != 0 ]
    then
        if chk_if_print_message "MAJOR"
        then
            cp $LOGFILE $WORKING_DIR/tmp/pg_dump_errors.out
            echo "MAJOR PG_DUMP_BACKUP alert - errors in pg_dump with database $database" | \
            ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
            exit '-1'
        fi # end if chk_if...
    else
        echo -e "\t***   pg_dump database: \t$database \tOK ***\n\t$(ls -l $DATA)" >> $LOGFILE
    fi

    echo "Remove old dump files, Dir: $DB_DUMP_DIR" >> $LOGFILE
    # remove old dump files
    if [ -z $DUMPSKEPTONDISK ]
    then
      find $DB_DUMP_DIR/*.dump -maxdepth 1 -type f -mtime +30 -exec ls -l {} \; >> $LOGFILE
      find $DB_DUMP_DIR/*.dump -maxdepth 1 -type f -mtime +30 -exec rm -f {} \; >> $LOGFILE
    else
      find $DB_DUMP_DIR/*.dump -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec ls -l {} \; >> $LOGFILE
      find $DB_DUMP_DIR/*.dump -maxdepth 1 -type f -mtime +${DUMPSKEPTONDISK} -exec rm -f {} \; >> $LOGFILE
    fi # end if DUMPSKEPTONDISK
done

# echo Success! Total backup size: `du -sh "$DUMP_DIR"`
fuji_subloppu >> $LOGFILE
# Poistetaan lopuksi mahdolliset turhat lipputiedostot
# (ja toisaalta sailytetaan kaytossa olevat)
rm_old_flag_files

exit 0

