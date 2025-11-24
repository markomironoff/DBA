#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_pgpool_common.sh,v $
##      $Revision: 1.3 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Yleiset pgpool rutiineihin liittyvat muuttujat
##
##      $Author: rosenjyr $
##      $Date:  2019/05/07 12:45:10 $
##
##      $Log: fuji_pgpool_common.sh,v $
##
# Revision 1.0  2016/02/18 09:54:15 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.2  2016/03/09 19:40:12  fijyrrose ()
# Lisatty chk_if_running tarkistus ettei rutiini ole jo ajossa
# 
# Revision 1.3  2019/05/07 12:45:10  fijyrrose ()
# Lisatty mahdollisuus useaan pgpool ymparistoon samalla palvelimella
# Lisatty pcp sammutusautomatiikan vaatimat maaritykset
# 
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/conf/fuji_pgpool_common.sh

# Base directory
WORKING_DIR=/home/fujitsu

# Load common routines
export PATH=$PATH:/usr/bin
. $WORKING_DIR/bin/fuji_common.sh

if [ -z $PGPOOL_SID ]
then
  my_sid=""
else
  my_sid=$(echo ".${PGPOOL_SID}")
  my_sid_path=$(echo "${PGPOOL_SID}")
fi

# Logfile
DATE=`date +%Y_%m_%d`
LOGFILE="$WORKING_DIR/log/$(basename $0)${my_sid}_${DATE}.log"

# Mahdollisuus antaa ymparistomuuttujatiedoston sijainti ymparistomuuttujassa
# (esim. jos useita PG-instansseja samalla palvelimella)
if [ -z $PGPOOLFUJIENV ]
then
  my_env_file=$HOME/pgpool${my_sid}.env
else
  my_env_file=$PGPOOLFUJIENV
fi

# Database information
if [ -f $my_env_file ]
then
.  $my_env_file
else
echo "ERROR: Tee $my_env_file tiedosto jossa PGPOOL-ympariston asetukset"
exit 1
fi

# PGPOOL configuration directory
if [ ! $PGPOOLCONF ]
then
PGPOOLCONF=/etc/pgpool-II
fi
# PGPOOL binary directory
if [ ! $PGPOOLHOME ]
then
PGPOOLHOME=/usr
fi
# Postgres client binary directory
if [ ! $PGHOME ]
then
PGHOME=/opt/fsepv10client64
fi
# Program names and paths
PCP_NODE_COUNT="$PGPOOLHOME/bin/pcp_node_count"
PCP_NODE_INFO="$PGPOOLHOME/bin/pcp_node_info"
PCP_ATTACH_NODE="$PGPOOLHOME/bin/pcp_attach_node"
PCP_NODE_INFO="$PGPOOLHOME/bin/pcp_node_info"
PCP_STOP_PGPOOL="$PGPOOLHOME/bin/pcp_stop_pgpool"
PSQL="$PGHOME/bin/psql"

# Login info
# Jos Postgres super user on sama kuin OS login user (esim. postgres) eika
# haluta kayttaa trust:a pg_hba.conf:ssa anna tyhjana
# muuten nailla tiedoin:
# PG_CONNECT_OPTS=" -h $PGHOST -p $PGPORT -U $PGUSER"
PG_CONNECT_OPTS=" "

# Haetaan tarvittavat tunnus- host, yms tiedot pgpool konfigurointitiedoista
export pg_check_user=$(grep "health_check_user" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export pg_check_password=$(grep "health_check_password" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export PGPASSWORD=$pg_check_password
export pg_check_port=$(grep "^port" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export num_init_children=$(grep "num_init_children" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export max_pool=$(grep "max_pool" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export health_check_timeout=$(grep "health_check_timeout" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export health_check_max_retries=$(grep "health_check_max_retries" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export health_check_retry_delay=$(grep "health_check_retry_delay" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")
export connect_timeout=$(grep "connect_timeout" $PGPOOLCONF/pgpool.conf | grep -v '^#' | grep "=" | awk -F"=" '{print $2}' | tr -d ' ' | tr -d "'")

TMPFILE=$WORKING_DIR/tmp/$(basename $0).$$

# Tarkistetaan ettei rutiini ole jo ajossa:
chk_if_running > /dev/null
if [ $? -gt 1 ]
then
    if chk_if_print_pgpool_message "WARNING"
    then
      echo "WARNING PGPOOL alert - routine $fuji_progname_base already running" | \
      ${WORKING_DIR}/bin/collect_alarms.sh $fuji_progname_base
    fi # end if chk_if...
 exit 1
fi
