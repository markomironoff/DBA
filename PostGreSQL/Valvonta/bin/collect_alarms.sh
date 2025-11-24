#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland 
##      Copyright (c) Fujitsu Finland 2011 - 2016
##
##      -----------------------------------------------------------------------
##      $RCSfile: collect_alarms.sh,v $
##      $Revision: 1.4 $
##
##	/**** FOR LINUX ****/
##
##
##      Contents: Kerataan ja jatkokasitellaan mm. PostgreSQL varmistuksilta, 
##                paallaolotarkistuksista Pgpool tarkistuksita, yms. tulleet viestit
##
##		Viestit ovat muotoa:
##      STATUS TARGET viesti (viesteja voi olla useita riveja)
##		jossa
##		STATUS = 	virheen vakavuusaste (vaihtelee valilla EMERGENCY - RESET)
##					(kts. xxxx_OHJE.doc)
##		TARGET =	kohde jonka ongelmista viesti on lahetetty 
##					(kts. xxxx_OHJE.doc)
##		esim.
##		CRITICAL PG_DUMPBACKUP alert - ongelmia Postgres dump varmistuksessa
##                
##
##      $Author: fijyrrose $
##      $Date: 2016/02/19  16:15:04 $
##
##      $Log: collect_alarms.sh,v $
##
# Revision 1.1  2015/02/02  14:19:04  fijyrrose ()
# Muutettu iclcheck/Patrol tiedoston nimen alkuun dba_
#
##
# Revision 1.2  2015/05/04  10:06:02  fijyrrose ()
# Lisatty PG_ONLINE_BACKUP ja PG_WAL_ARCHIVE_BACKUP ja PG_LOG_ARCHIVING
#
# Revision 1.3  2015/10/13  12:56:02  fijyrrose ()
# Lisatty Zabbix:ia varten WARNING ja UNKNOWN statukset joilla kuitenkin
# PATROL/iclcheck lipputiedostoon alkuun 0 (nolla)
#
# Revision 1.4  2016/02/19  16:15:04  fijyrrose ()
# Lisatty PGPOOL tarkistusten tulostus
##      -----------------------------------------------------------------------
#
# Sijainti: /home/fujitsu/bin/collect_alarms.sh
#
#
# Debug
# export VFY_ALL=1

. /home/fujitsu/bin/fuji_common.sh
#

#
fuji_get_time
date_time=${fuji_value}
date=$(echo $date_time | cut -d " " -f1)
time=$(echo $date_time | cut -d " " -f2)
hh=$(echo $time | cut -d ":" -f1)
myhost=`hostname`
endofmess="#...#\n"
# echo "date $date time: $time"

# Oletusarvoisesti ilmoituksesta ei laheteta sahkopostia
# send_mail=true
send_mail=false

WORKING_DIR=/home/fujitsu
PATROL_DIR=$WORKING_DIR/iclcheck
tmp_progname=$(echo $1 | awk -F "." '{print $1}')
tmp_progname=$(echo $tmp_progname | sed "s/fuji_/dba_/")
if [ -z $PG_SID ] && [ -z $PGPOOL_SID ]
then
  my_sid=""
else
  my_sid=$(echo ".${PG_SID}${PGPOOL_SID}")
fi
tmp_progname=$(echo "${tmp_progname}${my_sid}")
PATROL_FILE=$WORKING_DIR/iclcheck/${tmp_progname}


# Postien tilapaistiedosto josta ne lopulta lahetetaan vastaanottajalle
MAIL_TMP="${WORKING_DIR}/tmp/mail_tmp"
PG_MAIL_TMP=${MAIL_TMP}_pg
# Halyjen lokitiedosto
ALARM_LOG="${WORKING_DIR}/log/alarm_messages.out"
# Maksimi maara virheenselvityskomentoja (taulukoissa)
MAX_CMDS=4
# Seuraavaan oletusvastaanottaja (kaytetaan ellei mail aliasta ole .mailrc:ssa maaritelty)
# default_receiver="YLEISmail"
# -- testia: 
default_receiver="jyri.rosendal@fi.fujitsu.com"
# Jos seuraavaan false, ei mistaan virheesta tehda halya
send_error_message=true

# Laita seuraaviin oikeat komennot kohteiden lisatietojen hakemiseksi
PG_DUMP_BACKUP_command[1]="/bin/cat $WORKING_DIR/tmp/pg_dump_errors${my_sid}.out"
#
# Online varmistukseen liittyvat
PG_ONLINE_BACKUP_command[1]="/bin/cat $WORKING_DIR/tmp/pg_online_backup_errors${my_sid}.out"
#
# Wal arkistojen varmistuksiin liittyvat
PG_WAL_ARCHIVE_BACKUP_command[1]="/bin/cat $WORKING_DIR/tmp/pg_wal_archive_backup_errors${my_sid}.out"
#
# WAL lokien arkistointiin liittyvat
PG_LOG_ARCHIVING_command[1]="/bin/cat $WORKING_DIR/tmp/pg_wall_arc_to_dir_errors${my_sid}.out"
#
# PG_STATUS_CHK analysointikommennot
PG_STATUS_CHK_command[1]="/bin/cat $WORKING_DIR/tmp/postgres_main_errors${my_sid}.out"
PG_STATUS_CHK_command[2]="pg_ctl status"
#
# check_postgres viesteihin liittyvat
PGCHECK_command[1]="/bin/cat $WORKING_DIR/log/$1.log"
# 
# PGPOOL viesteihin liittyvat
PGPOOL_command[1]="/bin/cat $WORKING_DIR/log/$1.log"

# Viestien vakavuusasteet
# Maaritellaan ne priority-tasot joista lahetetaan email
# severities=( EMERGENCY CRITICAL MAJOR MINOR WARNING NORMAL RESET )
# severities=( EMERGENCY CRITICAL MAJOR )
severities=( EMERGENCY CRITICAL MAJOR WARNING UNKNOWN )

# Luetaan viestirivi(t) ja tehdaan jatkokasittely
#
# Viestissa voi olla useita riveja.
while read line
do
  # Otetaan ensimmainen rivi talteen (siina on status ja kohdetiedot -> saadaan mailille subject)
  if [ -z "${first_line}" ]
  then
    first_line=$line
  fi
  msg_tmp=`echo -e "${msg_tmp}${line}\n "`
done

msg=$(echo -e "$date_time $myhost: ${msg_tmp}")
echo "$msg" > $MAIL_TMP

# Seuraavassa tehdaan jatkotoimia first_line muuttujassa olevien status ja kohdetietojen perusteella
# Haetaan mm. emailien vastaanottaja, seka kerataan lisatietoa ongelmasta liitettavaksi emailiin
# 
status=$(echo $first_line | cut -d " " -f1)
target=$(echo $first_line | cut -d " " -f2)
# echo "status: $status target: $target"

# Tutkitaan viela halutaanko talla "vakavuusasteella" oleva
# viestia tehda halytys
if $send_error_message
then
  send_error_message=false
  for severity in ${severities[@]}
  do
    if [ "$severity" = "$status" ]
    then
      send_error_message=true
    fi
  done
  if ! $send_error_message
  then
    # Kirjoitetaan patrolfile
    if [ -d $PATROL_DIR ]
    then
      echo -e "0" > $PATROL_FILE
    fi
    exit 0
  fi
fi
# 
# Haetaan emailin vastaanottaja (maaritelty tiedostossa $HOME/.mailrc)
#
fuji_get_mail_alias $target
if [ -n "${fuji_value}" ]
then
  send_to=${fuji_value}
else
  send_to=$default_receiver
fi

# echo "send mail to: $send_to"

#
# Jos kohteelle maaritelty lisakomento, suoritetaan se
case "$target" in
  "PG_DUMP_BACKUP" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PG_DUMP_BACKUP_command[$i]}
        if [ -n "${isset}" ]
        then
	  echo -e "(/* Command: ${PG_DUMP_BACKUP_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PG_DUMP_BACKUP_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;
    
  "PG_STATUS_CHK" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PG_STATUS_CHK[$i]}
        if [ -n "${isset}" ]
        then
	  echo -e "(/* Command: ${PG_STATUS_CHK[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PG_STATUS_CHK[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;

  "PG_ONLINE_BACKUP" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PG_ONLINE_BACKUP_command[$i]}
        if [ -n "${isset}" ]
        then
          echo -e "(/* Command: ${PG_ONLINE_BACKUP_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PG_ONLINE_BACKUP_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;

  "PG_LOG_ARCHIVING" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PG_LOG_ARCHIVING_command[$i]}
        if [ -n "${isset}" ]
        then
          echo -e "(/* Command: ${PG_LOG_ARCHIVING_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PG_LOG_ARCHIVING_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;

  "PG_WAL_ARCHIVE_BACKUP" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PG_WAL_ARCHIVE_BACKUP_command[$i]}
        if [ -n "${isset}" ]
        then
          echo -e "(/* Command: ${PG_WAL_ARCHIVE_BACKUP_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PG_WAL_ARCHIVE_BACKUP_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;

  "PGCHECK" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PGCHECK_command[$i]}
        if [ -n "${isset}" ]
        then
          echo -e "(/* Command: ${PGCHECK_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PGCHECK_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;

  "PGPOOL" )
    for (( i=1; i<=$MAX_CMDS; i++ ))
    do
        isset=${PGPOOL_command[$i]}
        if [ -n "${isset}" ]
        then
          echo -e "(/* Command: ${PGPOOL_command[$i]} */)\n" 1>> $MAIL_TMP 2>/dev/null
          ${PGPOOL_command[$i]} 1>> $MAIL_TMP 2>/dev/null
          echo -e "\\n------------------------***------------------------\\n" 1>> $MAIL_TMP 2>/dev/null
        fi
    done
    ;;
    
  * )
	:
    ;;  
esac

echo -e $endofmess >> $MAIL_TMP
# Kirjoitetaan ilmoitus lokiin ja lahetetaan email jossa virheilmoitus+lisatietoa
# echo -e "$msg" >> $ALARM_LOG
cat $MAIL_TMP >> $ALARM_LOG
# echo -e "$msg" | mailx -s "${first_line}" $send_to

# Tutkitaan viela halutaanko talla "vakavuusasteella" oleva
# viestia tehda halytys
if $send_error_message
then
  send_error_message=false
  for severity in ${severities[@]}
  do
    if [ "$severity" = "$status" ]
    then
      send_error_message=true
    fi
  done
fi

# 
if $send_error_message
then
  if $send_mail
  then
    mailx -s "${first_line}" $send_to < $MAIL_TMP
  fi
  # Kirjoitetaan patrolfile
  if [ -d $PATROL_DIR ]
  then
    # Seuraavat jotta saadaan Zabbixille tulostettua merkkijonohaulla myos varoitukset
    if [ "$status" = "WARNING" -o "$status" = "UNKNOWN" ]
    then
      echo -e "0 $first_line" > $PATROL_FILE
    else
      echo -e "1 $first_line" > $PATROL_FILE
    fi
  fi
  # Lahetateen Postgres prosessihalyista lisaksi erikseen tietoa, mm. sql-lause.
  # Paattely siita lahetetaanko vai ei tehdaan tiedoston $PG_MAIL_TMP
  # olemassaolon perusteella
  if [ -r $PG_MAIL_TMP ]
  then
    #
    # Haetaan emailin vastaanottaja (maaritelty tiedostossa $HOME/.mailrc)
    #
    fuji_get_mail_alias "POSTGRES"
    if [ -n "${fuji_value}" ]
    then
      send_to=${fuji_value}
    else
      send_to=$default_receiver
    fi
    mailx -s "${first_line}" $send_to < $PG_MAIL_TMP
    rm -f $PG_MAIL_TMP
  fi # end if -r PG_MAIL
fi # end if send_error_message
exit 0
