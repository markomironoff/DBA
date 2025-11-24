#! /bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland
##      Copyright (c) Fujitsu Finland 2011 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_check_pgpool_common.sh,v $
##      $Revision: 1.1 $
##
##      /**** FOR LINUX ****/
##
##      Contents: Pgpool tarkistukseen liittyvat muuttujat ja raja-arvot 
##
##      $Author: rosenjyr $
##      $Date: 2019/05/15 15:07:23 $
##
##      $Log: fuji_check_pgpool_common.sh,v $
##
# Revision 1.0  2016/02/18 07:11:13 fijyrrose ()
# Ensimmainen versio
#
# Revision 1.1  2019/05/15 15:07:23 fijyrrose ()
# Lisatty mahdollisuus ajaa useampaa pgpoolia samassa palvelimessa
#
##      -----------------------------------------------------------------------
#
#
# Sijainti: /home/fujitsu/conf/fuji_check_pgpool_common.sh

# Base directory
WORKING_DIR=/home/fujitsu

# check_pgpool fujitsu routines directory
FUJI_CHECK_POSTGRES_DIR=/home/fujitsu/check_pgpool
# Load common definitions
. $WORKING_DIR/conf/fuji_pgpool_common.sh

# Kayttajatunnus PCP-komennoille
PCP_USER=pcpuser

# pgpool host names
# Seuraavaan voi antaa useampia pilkulla erotettuna
# Anna hostname, tai IP jotka on aaritelty pool_hba.conf:iin, esim.
# host   all         all         192.168.10.0/24       md5
PGPOOL_HOSTS="192.168.10.4"

# check_pgpool alarm threshol values

# Seuraavaan sitten jotain raja-arvoja
## Kaytetyt yhteydet pgpoolin num_int_children osoittamasta maks. arvosta
## Joko prosentteina tai todellinen arvo
## esim. 85%, tai 170
NUM_INIT_CHILDREN_WARNING="85%"
NUM_INIT_CHILDREN_CRITICAL="95%"
# Timeout tarkistuskomentojen suoritukseen. (sekuntteja) 
# Aja ylitys lopettaa komennon ja paatyy virheeseen (=nostaa halytyksen)
COMMAND_TIMEOUT=15

##########################################################
# Asetataan mahdolliset instanssikohtaiset valvonta-arvot
###########################################################
if [ -z $(eval echo \$\{NUM_INIT_CHILDREN_WARNING$PGPOOL_SID\}) ]
then
NUM_INIT_CHILDREN_WARNING=$NUM_INIT_CHILDREN_WARNING
else
NUM_INIT_CHILDREN_WARNING=$(eval echo \$\{NUM_INIT_CHILDREN_WARNING$PGPOOL_SID\})
fi
if [ -z $(eval echo \$\{NUM_INIT_CHILDREN_CRITICAL$PGPOOL_SID\}) ]
then
NUM_INIT_CHILDREN_CRITICAL=$NUM_INIT_CHILDREN_CRITICAL
else
NUM_INIT_CHILDREN_CRITICAL=$(eval echo \$\{NUM_INIT_CHILDREN_CRITICAL$PGPOOL_SID\})
fi
if [ -z $(eval echo \$\{COMMAND_TIMEOUT$PGPOOL_SID\}) ]
then
COMMAND_TIMEOUT=$COMMAND_TIMEOUT
else
COMMAND_TIMEOUT=$(eval echo \$\{COMMAND_TIMEOUT$PGPOOL_SID\})
fi

