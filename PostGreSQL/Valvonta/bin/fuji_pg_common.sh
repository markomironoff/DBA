#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2015
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_common.sh,v $
##      $Revision: 1.3 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleiset PostgreSQL rutiineihin liittyvat muuttujat
##
##      $Author: rosenjyr $
##      $Date: 2011/12/20 14:10:03 $
##
##      $Log: fuji_pg_common.sh,v $
##
# Revision 1.1  2011/12/20 14:10:03  fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2015/05/04 10:19:05  fijyrrose ()
# Lisatty online ja wal arkistojen varmistuksiin liittyvat muuttujat
# Lisatty wal arkistointiin liittyvat muuttujat
# Siirretty dump varmistuksiin liittyvat muuttuja varsinaisesta rutiinista tanne
#
# Revision 1.3  2015/06/02 07:54:10  fijyrrose ()
# Lisatty PG_CTL muuttujaan pg_ctl ohjelma polkuineen
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_common.sh

# Base directory
WORKING_DIR=/home/fujitsu

# Load common routines
. $WORKING_DIR/bin/fuji_common.sh

# Logfile
DATE=`date +%Y_%m_%d`
LOGFILE="$WORKING_DIR/log/$(basename $0)_${DATE}.log"

# Database information
. /opt/postgres/9.3/pg93-openscg.env

# Database host server
if [ ! $PGHOST ]
then
PGHOST=localhost
fi

if [ ! $PGUSER ]
then
  PGUSER=postgres
fi

if [ ! $PGHOME ]
then
  PGHOME=/opt/postgres/9.3
fi

if [ ! $PGDATA ]
then
  PGDATA=/data/pgdata/9.3/data
fi

# Varmistuslokien sailytysaika (vuorokautta)
BACKUPLOGRETENTIONTIME=14
# Lippu merkiksi online backup menossa
BACKUP_FLAG_FILE=$PGDATA/online_backup_is_going
# Lippu merkiksi archive backup menossa
ARC_BACKUP_FLAG_FILE=$PGDATA/archive_backup_is_going

## Seuraaviin hakemistomuuttujiin tieto seuraavasti:
## - Jos tiedot on tarkoitus kopioida suoraan
##   remote palvelimelle (kts. REMOTESERVERTOMOVE)
##   maarittele pelkastaan REMOTEDIR muuttuja.
## - Jos varmistus tehdaan seka paikalliselle, etta
##   remote palvelimen (kts. REMOTESERVERTOCOPY)
##   levylle maarittele kummatkin
##   DIR muuttujat.
## - Jos varmistus tehdaan ainoastaan paikalliselle
##   (voi olla myos NFS) levylle anna
##   pelkastaan ONLINE_BACKUP_DIR
##   HUOM! Tarkista talloin etta REMOTESERVERTOMOVE muuttujaa
##   ei ole maaritelty
# Backup Directory
ONLINE_BACKUP_DIR="/pgbackup/pg_online_backups"
# Tai Remote hakemisto jonne kopioidaan/siirretaan
# REMOTEDIR=/remotedir

# WAL archive directory
# WALL_ARC_DIR=/smalldisk2/pgarchive
WALL_ARC_DIR=/pgarchive
# WAL arkistointirutiini ei tee muuta kuin palauttaa OK koodin,
# jos seuraavassa on arvo Y
# Tata voi kayttaa esimerkiksi tilanteessa jossa arkistointi
# halutaan keskeyttaa, eika kantaa kuitenkaan voida ajaa alas/reload:ta.
DONOTDOARCHIVING=
# WAL arkistointi keskeytetaan ja arkistointirutiini palauttaa
# error-koodin jos seuraavassa on arvo Y.
# Talloin WAL lokeja ei vapauteta/poisteta, vaan niita kertyy
# lisaa niin kauan kuin tama on arvossa Y (tai levy tulee tayteen)
# Voidaan kayttaa ainakin testauksiin.
CANCELWALARCHIVING=
#  WAL archiving only during online data backup (Y/N/tyhja)
# HUOM! Ala kayta muuta kuin silloin jos haluat
# arkistot talteen ainoastaan varmistuksen ajalta.
# Kun tama on paalla ei WAL lokeja normaalist arkistoida
# mutta arkistointi palauttaa siita huomimatta ok-koodin.
# HUOM!HUOM! Ala kayta toistaiseksi
# pitaa viela selvittaa miten saadaan kesken olevat
# tapahtumat hanskattua
ONLYCOPYDURINGBACKUP=
# Keskeyta WAL archiving during archive backup and cleaning
# HUOM! Anna olla arvossa Y
BREAKCOPYDURINGARCBACKUP=Y
# Kuinka monen paivan varmistukset sailytetaan levylla 
# Jollei muuttujaa maarittella sailytetaan kaikki varmistukset
# ja niiden poisto pitaa hoitaa taman rutiinin ulkopuolella.
BACKUPSKEPTONDISK=1
# BACKUPRETENTIONTIME=7
# Jos haluat siirtaa TAI kopioida varmistustiedostot
# jollekin remote palvelimelle anna tassa palvelimen nimi ja hakemisto jonne kopioidaan
#
############################################################################################################################################
# HUOM! Tee ssh kirjautuminen ilman salasanaa mahdolliseksi seuraavasti:
# [postgres@postgresql93_master ~]$ id
# uid=500(postgres) gid=54324(postgres) groups=54324(postgres),54323(vboxsf)
# [postgres@postgresql93_master ~]$ pwd
# /home/postgres
# [postgres@postgresql93_master ~]$ ssh-keygen -t rsa
# Generating public/private rsa key pair.
# Enter file in which to save the key (/home/postgres/.ssh/id_rsa): 
# Enter passphrase (empty for no passphrase): 
# Enter same passphrase again: 
# Your identification has been saved in /home/postgres/.ssh/id_rsa.
# Your public key has been saved in /home/postgres/.ssh/id_rsa.pub.
# The key fingerprint is:
# 3d:49:f7:b4:c9:8a:c2:18:39:65:62:b0:56:40:a3:d7 postgres@postgresql93_master.localdomain
#
# [postgres@postgresql93_master ~]$ cat ~/.ssh/id_rsa.pub | ssh postgres1@postgresql93_replica "mkdir -p ~/.ssh && cat >>  ~/.ssh/authorized_keys"
#
# HUOM! Tarkista että käyttään kotihakemistoon ei ole muilla kirjoitusoikeuksia, 
# esim. 740 .ssh hakemiston oikeudet on 700 ja kaiken sen alla olevan 600.
#
####################################################################################################################################################
# HUOM! Seuraaviin arvo vain jompaan kumpaan - ei molempiin! (tai sitten ei kumpaakaan)
# Anna palvelin/hakemisto jonne siirretaan
# REMOTESERVERTOMOVE=postgresql93_master
REMOTESERVERTOMOVE=
# Tai jos haluat ainoastaan kopioida
REMOTESERVERTOCOPY=

# Dump varmistushakemisto
# Huom! Taman alle tulee jokaselle kannalle oma hakemisto (rutiini luo ne)
DUMP_DIR=/pgbackup/pg_dumps
# PG_DUMP options:
DUMP_OPTS="--create --format custom --blobs --serializable-deferrable --lock-wait-timeout=30000"
# PG_DUMP metadata
DUMP_OPTS_META="--create --schema-only --format plain --blobs --serializable-deferrable --lock-wait-timeout=30000"

# Program names and paths
DUMPALL="$PGHOME/bin/pg_dumpall"
PGDUMP="$PGHOME/bin/pg_dump"
PSQL="$PGHOME/bin/psql"
PG_CTL="$PGHOME/bin/pg_ctl"
PG_ARCHIVECLEANUP="$PGHOME/bin/pg_archivecleanup"
# Seuraavaa tarvitaan jollei postgresqlxx-contrib pakettia ole asennettuna
# PG_ARCHIVECLEANUP="/home/fujitsu/bin/my_pg_archivecleanup.sh"

# Login info
# Jos Postgres super user on sama kuin OS login user (esim. postgres) eika
# haluta kayttaa trust:a pg_hba.conf:ssa anna tyhjana
# muuten nailla tiedoin:
# PG_CONNECT_OPTS=" -h $PGHOST -p $PGPORT -U $PGUSER"
PG_CONNECT_OPTS=" "

TMPFILE=$WORKING_DIR/tmp/$(basename $0).$$
