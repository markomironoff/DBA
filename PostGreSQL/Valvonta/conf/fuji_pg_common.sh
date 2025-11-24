#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2021
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pg_common.sh,v $
##      $Revision: 2.0 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleiset PostgreSQL rutiineihin liittyvat muuttujat
##
##      HUOM! Jos kaytat FEP:n online varmistusta maarittele tahan tiedostoon
##      ainoastaan ymparistomuuttujien sisaltavan tiedoston ajon, seka
##      DUMP-alkuiset muuttujat.
##
##      $Author: rosenjyr $
##      $Date:  2022/11/09 14:55:44 $
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
# Revision 1.4  2015/12/28 09:18:05  fijyrrose ()
# Muutettu WAl arkistojen kopioinnin aikaista arkistointia
# ohjaavan parameterin BREAKCOPYDURINGARCBACKUP oletusarvoa
# niin etta kirjoitetaan arkistoja samalla kuin
# vanhempia varmistetaan
#
# Revision 1.5  2016/02/19 09:54:15  fijyrrose ()
# Lisatty dumppien sailytysaikaa osoittava muuttuja DUMPSSKEPTONDISK
#
# Revision 1.6  2016/03/09 19:40:12  fijyrrose ()
# Lisatty chk_if_running tarkistus ettei rutiini ole jo ajossa
#
# Revision 1.7  2016/12/09 08:02:22  fijyrrose ()
# Lisatty mahdollisuus osoittaa ymparistomuuttujatiedoston sijainti muuttujalla
# (esim. jos samalla palvelimella useita instansseja)
#
# Revision 1.8  2018/06/21 10:55:45  fijyrrose ()
# Lisatty mahdollisuus ajaa monen instanssin ymparistossa
#
# Revision 1.9  2020/11/09 14:55:44  fijyrrose ()
# Monen instanssin ymparistossa huomioidaan myos varmistuslevyt
#
# Revision 2.0  2022/11/09 14:55:44  fijyrrose ()
# Lisatty malli pg_dump varmistukset maarittelysta rinnakkaiseksi
# HUOM! Maarittele max 1/2 kokonais core maarasta, ettei hairitse muuta tuotantoa
# Kts. muuttuja DUMP_OPTS
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/bin/fuji_pg_common.sh

# Base directory
WORKING_DIR=/home/fujitsu

# Load common routines
. $WORKING_DIR/bin/fuji_common.sh

if [ -z $PG_SID ]
then
  my_sid=""
  bck_sid="inst1"
else
  my_sid=$(echo ".${PG_SID}")
  my_sid_path=$(echo "${PG_SID}")
  bck_sid=$PG_SID
fi
# Logfile
DATE=`date +%Y_%m_%d`
LOGFILE="$WORKING_DIR/log/$(basename $0)${my_sid}_${DATE}.log"

# Mahdollisuus antaa ymparistomuuttujatiedoston sijainti ymparistomuuttujassa
# (esim. jos useita PG-instansseja samalla palvelimella)
if [ -z $PGFUJIENV ]
then
  my_env_file=$HOME/pg${my_sid}.env
else
  my_env_file=$PGFUJIENV
fi

# Database information
if [ -f $my_env_file ]
then
.  $my_env_file
else
# . /opt/postgres/9.3/pg93-openscg.env
echo "ERROR: Tee $my_env_file tiedosto jossa PG-ympariston asetukset"
exit 1
fi

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
  PGHOME=
fi

if [ ! $PGDATA ]
then
  PGDATA=
fi

my_hostname=`hostname -s`
# Valvonta/varmistus lokien sailytysaika (vuorokautta)
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
ONLINE_BACKUP_DIR="/pgbackup/${bck_sid}/pg_online_backups"
# TAI Remote hakemisto jonne kopioidaan/siirretaan
# REMOTEDIR=/remotedir

# WAL archive directory
WALL_ARC_DIR=/pgbackup/${bck_sid}/archive
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
# HUOM! Normaalitilanteessa olla arvossa N,
# muuten vilkaassa tilanteessa saataa pg_xlog tayttya
BREAKCOPYDURINGARCBACKUP=N
# Kuinka monen paivan online varmistukset sailytetaan levylla
# Jollei muuttujaa maarittella sailytetaan kaikki varmistukset
# ja niiden poisto pitaa hoitaa taman rutiinin ulkopuolella.
# Jos arvo on -1 tyhjataan varmistushakemisto ennen uutta varmistusta
# HUOM! ei koske fuji_pg_basebackup:lla tehtyja varmistuksia joita on levylla
# ainoastaa viimeisin (+ varmistuksen ajan edellinen)
BACKUPSKEPTONDISK=-1
# Seuraava ei viela kaytossa
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
# HUOM! Seuraaviin arvo vain jos tietoja kopioidaan/siirretaan remote serverille
# Anna arvo ainoastaan jompaan kumpaan - ei molempiin! (tai sitten ei kumpaakaan)
# Anna palvelin/hakemisto jonne siirretaan
REMOTESERVERTOMOVE=
# Tai jos haluat ainoastaan kopioida
REMOTESERVERTOCOPY=

##
## pg_dump varmistuksen maaritykset:
##
# Kuinka monen paivan dump varmistukset sailytetaan levylla
# HUOM! poistossa kaytetaan dump tiedostojen mtime arvoa,
# joskus voi varmistus jakautua eri vuorokausille joten
# osa dumpeista voidaan poistaa eri aikaan
# Arvolla -1 poistetaan varmistushakemiston vanha sisalto ennen varmistuksen ajoa
# Jollei muuttujaa maarittella sailytetaan 30 vuorokautta
DUMPSKEPTONDISK=-1
# Dump varmistushakemisto
# Huom! Taman alle tulee jokaselle kannalle oma hakemisto (rutiini luo ne)
DUMP_DIR=/pgbackup/${bck_sid}/pg_dumps
# PG_DUMP options:
DUMP_OPTS="--create --format custom --blobs --serializable-deferrable --lock-wait-timeout=30000"
# Rinnaikkais dump. Maarittele rinnakkaisuudeksi (-j) max 1/2 kokonais core-maarasta
# DUMP_OPTS="--create --format directory --compress=2 -j 2 --blobs --serializable-deferrable --lock-wait-timeout=30000"
# PG_DUMP metadata
DUMP_OPTS_META="--create --schema-only --format plain --blobs --serializable-deferrable --lock-wait-timeout=30000"
# Anna seuraavaan Y jos haluat ajaa pelkan metadatan -> luontilauseet
DUMP_META_ONLY=

##
## pg_basebackup varmistuksen maaritykset:
##
# Arvolla -1 poistetaan varmistushakemiston vanha sisalto ennen varmistuksen ajoa
# Jollei muuttujaa maaritella sailytetaan edellinen varmistus siihen asti kun
# ajossa oleva on mennyt onnistuneesti lapi
BASEBACKUPSKEPTONDISK=-1
#
# Varmistus otetaan aikaisemmin tassa tiedostossa maaritellyn muuttujan
# ONLINE_BACKUP_DIR osoittamaan paikkaan
# Anna seuraavaan muuttujaan kopiointikomento jos haluat kayttaa jotain muuta kuin oletuskomentoa
# Oletus on: pg_basebackup -x -D $ONLINE_BACKUP_DIR -Ft
# HUOM! Jos muutat komentoa huolehdithan siita etta mahdolliset taulualueet tulee varmistettua
PG_BASEBACKUP_CMD="$PGHOME/pg_basebackup -X f -D $ONLINE_BACKUP_DIR -Ft"
# PG_BASEBACKUP_CMD="tar -cjf $ONLINE_BACKUP_DIR/online.tar.bz2 $PGDATA"
# Seuraavassa maarataan otetaanko basebackupin jalkeen varmistukset
# myos mahdollisista wal-arkistoista
# HUOM! Jollei tata + lokien arkistointia ole maariteltyna
# on varmistuttava siita etta aktiiveja wal-lokeja on tarpeeksi
# (wal_keep_segments)
# Arvot: Y/N/tyhja
BASEBACKUP_DO_ARCHIVE_BACKUP=Y

# Program names and paths
DUMPALL="$PGHOME/pg_dumpall"
PGDUMP="$PGHOME/pg_dump"
PSQL="$PGHOME/psql"
PG_CTL="$PGHOME/pg_ctl"
PG_ARCHIVECLEANUP="$PGHOME/pg_archivecleanup"
PG_BASEBACKUP="$PGHOME/pg_basebackup"
# Seuraavaa tarvitaan jollei postgresqlxx-contrib pakettia ole asennettuna
PG_ARCHIVECLEANUP="/home/fujitsu/bin/my_pg_archivecleanup.sh"

# Login info
# Jos Postgres super user on sama kuin OS login user (esim. postgres) eika
# haluta kayttaa trust:a pg_hba.conf:ssa anna tyhjana
# muuten nailla tiedoin:
# PG_CONNECT_OPTS=" -h $PGHOST -p $PGPORT -U $PGUSER"
if [ -z $PG_SID ]
then
  PG_CONNECT_OPTS=" "
else
  if [ "$PG_REMOTE_CONNECT" = "true" ]
  then
    PG_CONNECT_OPTS=" -h $PGHOST"
  else
    PG_CONNECT_OPTS=" "
  fi
fi

TMPFILE=$WORKING_DIR/tmp/$(basename $0)${my_sid}.$$

# Tarkistetaan ettei rutiini ole jo ajossa:
chk_if_running > /dev/null
if [ $? -gt 1 ]
then
    if chk_if_print_pgpool_message "WARNING"
    then
      echo "WARNING PGCHECK alert - routine $fuji_progname_base already running" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
 exit 1
fi

