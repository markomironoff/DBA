#!/bin/bash
##      -----------------------------------------------------------------------
##
##      Fujitsu Finland 
##      Copyright (c) Fujitsu Finland 2011 - 2019
##
##      -----------------------------------------------------------------------
##      $RCSfile: fuji_common.sh,v $
##      $Revision: 1.7 $
##
##      Contents: Yhteiskayttoiset shell scriptifunktiot 
##                
##
##      $Author: root $
##      $Date:  2019/05/15  14:45:20 $
##
##      $Log: fuji_common.sh,v $
##
# Revision 1.1  2015/02/02  14:25:14  fijyrrose ()
# Muutettu iclcheck/Patrol tiedoston nimen alkuun dba_
#
# Revision 1.2  2015/05/04  10:11:02  fijyrrose ()
# Toistuvassa virhetilanteessa ei kirjoiteta patrol statustiedostoon mitaan
# muutetaan ainoastaan tiedoston aikaleimaa
#
# Revision 1.3  2016/03/08  19:38:12  fijyrrose ()
# Lisatty funktio chk_if_running
#
# Revision 1.4  2016/04/13  14:59:12  fijyrrose ()
# Funktioon chk_if_running lisatty tarkistuksia ajossa olevien rutiineiden selvittamiseksi
#
# Revision 1.5  2016/12/20  12:05:10 fijyrrose ()
# Korjattu viela chk_if_running rutiinin toimintaa niin etta pid numerolla pitaa
# olla juuri nimenomainen ajettava prosessi kaynnissa etta halytetaan
#
# Revision 1.6  2018/06/21  10:50:30 fijyrrose ()
# Lisatty mahdollisuus ajaa monen instanssin ymparistossa
#
# Revision 1.7  2019/05/15  14:45:20 fijyrrose ()
# Lisatty mahdollisuus ajaa monen pgpoolin ymparistossa
#
# Revision 1.8  2019/06/12  10:02:30 fijyrrose ()
# Lisatty chk_if_pg_is_in_recovery funktio kannan replikoinnin
# standby roolin tunnistamiseksi
##
##      -----------------------------------------------------------------------
# 
#
# Sijainti: /home/fujitsu/bin/fuji_common.sh
#
# ======================================================================
# Initial setup, default values, etc.
# ======================================================================
fuji_progname=$0
fuji_progname_base=$(basename -- $fuji_progname)
if [ -z $PG_SID ] && [ -z $PGPOOL_SID ]
then
  my_sid=""
else
  my_sid=$(echo ".${PG_SID}${PGPOOL_SID}")
fi
fuji_progname_base=$(echo "${fuji_progname_base}${my_sid}")

fuji_value=
fuji_logfile=/dev/stdout
fuji_errorfile=/dev/stderr
fuji_commandlog=/dev/null
fuji_args="${@}"
fuji_mail_proc="/usr/bin/mailx"
fuji_mail_textfile="/tmp/mailtext"
fuji_error_mail=
fuji_warning_mail=
fuji_info_mail=
fuji_mail_to=


_fuji_ERROR_STR="*** ERROR:"
_fuji_WARN_STR="*** Warning:"
_fuji_INFO_STR="*** Info:"
_fuji_QUERY_STR="*** Kysely:"
_fuji_STACKTRACE_STR="*** STACKTRACE:"
readonly _fuji_ERROR_STR _fuji_WARN_STR _fuji_INFO_STR _fuji_QUERY_STR _fuji_STACKTRACE_STR


_fuji_trace=
_fuji_starttime=
_fuji_endtime=

# Varikoodit
ESC="\x1b["
COL_BLUE="${ESC}34;01m"
COL_RED="${ESC}31;01m"
COL_RESET="${ESC}39;49;00m"

#==============================================================================
#
# Funktio: fuji_get_mail_alias
#
#	Funktiolla haetaan mail alias valvontarutiineiden kayttoon 
# 
#               
#      
#==============================================================================
fuji_get_mail_alias() 
{ 
  local my_alias
  fuji_value=""
  if [ -f $HOME/.mailrc ]
  then
    if [ "`grep "${1}mail" $HOME/.mailrc`" ]
    then
      fuji_value="${1}mail" 
      return 0 
    fi
  fi
  
  return 1
} # === End of fuji_get_mail_alias() === #
# readonly -f fuji_get_mail_alias


#==============================================================================
#
# Funktio: fuji_get_time:
#
#	Funktiolla tulostaa ajan muodossa pv.kk.vv hh24:mi
# 
#               
#      
#==============================================================================
fuji_get_time() 
{ 
  local date_time
  date_time=$(date +%d.%m.%y\ %H:%M)
  fuji_value="${date_time}"
  return 0 
} # === End of fuji_get_time() === #
# readonly -f fuji_get_time

#==============================================================================
#
# Funktio: fuji_get_seconds:
#
#	Funktiolla haetaan aika sekuntteina (01.01.1970 j‰lkeen)
#   	- aikaa voidaan k‰ytt‰‰ vaikkapa keston laskemiseen (loppuaika - alkuaika)
#               
#
# Paluuarvo:
#	int     aika  
#      
#==============================================================================
fuji_get_seconds()
{
  fuji_stacktrace "${@}"
  local seconds
  seconds=$(date +%s)
  fuji_value="${seconds}"
  return ${fuji_value}

} # === End of fuji_get_seconds() === #
# readonly -f fuji_get_seconds

#==============================================================================
#
# Funktio: fuji_duration:
#
#	Funktiolla lasketaan kesto (loppuaika - alkuaika)
#
# Parametrit:
#	$1		alkuaika <pakollinen> 
#	$2		loppuaika <pakollinen>      
#               
#
# Paluuarvo:
#	int     aika  
#      
#==============================================================================
fuji_duration()
{
  fuji_stacktrace "${@}"
  local duration  
  if [ -z "$1" -a -z "$2" ]
  then
    return x
  fi
  duration=`expr $2 - $1`
  # duration=`expr $duration \* 10`
  fuji_value="${duration}"
  return 0

} # === End of fuji_duration() === #
# readonly -f fuji_duration

#==============================================================================
#
# Funktio: fuji_secs_to_hhmmss:
#
#	Funktiolla muutetaan sekuntit muotoon hh:mm.ss 
#               
#
# Paluuarvo:
#	string     aika  
#      
#==============================================================================
fuji_secs_to_hhmmss()
{
  fuji_stacktrace "${@}"
  local minutit 
  local tunnit 
  local sekunnit
  ((minuutit=$1/60))
  ((sekunnit=$1-$minuutit*60))
  ((tunnit=$minuutit/60))
  ((minuutit=$minuutit-$tunnit*60))

  fuji_value="${tunnit}:${minuutit}:${sekunnit}"
  return 0

} # === End of fuji_secs_to_hhmmss() === #
# readonly -f fuji_secs_to_hhmmss

#==============================================================================
#
# Funktio: fuji_init_logfile:
#
#	Funktiolla alustetaan loki-, virhe- ja komentolokitiedostot.
#	Lokitiedostojen nimi on muotoa:
#   - komentoskipti_vvkkpv.log
#   - komentoskipti_vvkkpv.err
#   - komentoskipti_vvkkpv.cmd
#
# Parametrit:
#	$1		Hakemisto jonne lokit kirjoitetaan <pakollinen>                     
#
# Paluuarvo:
#	int     Status koodi  
#      
#==============================================================================
fuji_init_logfile()
{
  fuji_stacktrace "${@}"
  local DIR;
  if [ -z "$1" ]
  then
  	_fuji_nolog=1
    return
  fi
  DIR=$1
  shift
  
  if [ -e "${DIR}" -a ! -d "${DIR}" ]
  then
    if [ -n "$1" ]
    then
      fuji_error_multi "${DIR} exists, but is not a directory." "$1"
    else
      fuji_error "${DIR} exists, but is not a directory."
    fi
  fi

  if [ ! -e "${DIR}" ]
  then
    mkdir -p "${DIR}"
    if [ ! -e "${DIR}" ]
    then
      fuji_error "Creating ${DIR} directory failed."
    fi
  fi
  
  if [ ! -z "$fuji_commandlog" ]
  then 
  	if [ "$fuji_commandlog" = "y" ]
  	then
	  	fuji_commandlog="${DIR}/`basename $0`_`date '+%y%m%d'`.cmd"
	  	touch ${fuji_commandlog}
	  	if [ $? -ne 0 ]
	  	then
	      fuji_error "Can not create commandlog ${fuji_commandlog}"
  		fi
  	else
  		fuji_commandlog=
  	fi
  fi
  
  fuji_logfile="${DIR}/`basename $0`_`date '+%y%m%d'`.log"
  fuji_errorfile="${DIR}/`basename $0`_`date '+%y%m%d'`.err"
  touch ${fuji_logfile}
  if [ $? -ne 0 ]
  then
      fuji_error "Can not create logfile ${fuji_logfile}"
  fi  

  touch ${fuji_errorfile}
  if [ $? -ne 0 ]
  then
      fuji_error "Can not create errfile ${fuji_errorfile}"
  fi    
  return 0
  } # === End of fuji_init_logfile() === #
# readonly -f fuji_init_logfile

# ======================================================================
# Routine: fuji_subalku
#
# ======================================================================
fuji_subalku()
{
  fuji_stacktrace "${@}"
  if [ -n "$_fuji_nolog" ]
  then
    return
  fi  
  if [ -z "${fuji_logfile}" ]
  then
  	return
  fi
  if [ ! -w "${fuji_logfile}" ]
  then
  	fuji_error "Can not write to log file ${fuji_logfile}."
  fi
  # Otetaan aloitusaika talteen keston laskemista varten
  fuji_get_seconds
  _fuji_starttime=$fuji_value

  echo "*=*HEADER==============================================================" >> $fuji_logfile
  echo "*=*Date: `date`" >> $fuji_logfile
  echo "*=*Script: $0" >> $fuji_logfile
  echo "*=*Args: $fuji_args" >> $fuji_logfile
  echo "*=*Node: `hostname`" >> $fuji_logfile
  echo "*=*User: ${USER:-\"$LOGNAME\"}" >> $fuji_logfile
  if [ -n "$1" ]
  then
    echo "*=*Descr: $1" >> $fuji_logfile
  fi
  echo "*=*" >> $fuji_logfile  
  echo "*=*BODY==============================================================" >> $fuji_logfile  
  
  
  $_fuji_trace
  return 0
} # === End of fuji_subalku() === #
# readonly -f fuji_subalku

# ======================================================================
# Routine: fuji_subloppu
#
# ======================================================================
fuji_subloppu()
{
  fuji_stacktrace
  if [ -n "$_fuji_nolog" ]
  then
    return
  fi    
  if [ -z "${fuji_logfile}" ]  
  then
  	return
  fi  
  if [ ! -w "${fuji_logfile}" ]
  then
  	fuji_error "Can not write to log file ${fuji_logfile}."
  fi
  # Lasketaan kesto

  if [ -n "$_fuji_starttime" ]
  then
    fuji_get_seconds
    _fuji_endtime=$fuji_value
    fuji_duration $_fuji_starttime $_fuji_endtime
    my_tmp=$fuji_value
    fuji_secs_to_hhmmss $my_tmp
    my_duration=$fuji_value
  fi


  echo "*=*TRAILER=============================================================" >> $fuji_logfile
  echo "*=*Date: `date`" >> $fuji_logfile
  if [ -n "$my_duration" ]
  then
    echo "*=*Duration: $my_duration (hh:mm:ss)" >> $fuji_logfile
  fi
  echo "*=*END==============================================================" >> $fuji_logfile  
  
  
  $_fuji_trace
  return 0
} # === End of fuji_subloppu() === #
# readonly -f fuji_subloppu


# ======================================================================
# Routine: fuji_run
#   prints the supplied command line
#   executes it
#   returns the error status of the command
# Example: fuji_run rm -f /etc/config-file
# ======================================================================
fuji_run()
{
  set +x # don't trace this, but we are interested in who called
  local rstatus
  fuji_stacktrace # we'll see the arguments in the next statement
  if [ ! -w ${fuji_commandlog} ]
  then
  	echo "${@}" 1>&2
  else
  	echo "$(date): ${@}" >> $fuji_commandlog
  fi
  ${@}
  rstatus=$?
  $_fuji_trace
  return $rstatus
} # === End of fuji_run() === #
# readonly -f fuji_run




# ======================================================================
# Routine: fuji_error
#   Prints the (optional) error message $1, then
#   Exits with the error code contained in $? if $? is non-zero, otherwise
#     exits with status 1
#   All other arguments are ignored
# Example: fuji_error "missing file"
# NEVER RETURNS
# ======================================================================
fuji_error()
{
  local errorcode=$?
  set +x # don't trace this, but we are interested in who called
  fuji_stacktrace # we'll see the arguments in the next statement
  if ((errorcode = 0))
  then
    errorcode=1
  fi
  touch $fuji_mail_textfile  
  if [ -n "$fuji_error_mail" -a "$fuji_error_mail" = "1" -a -w $fuji_mail_textfile ]
  then
	  fuji_subloppu
	  echo "*=*Date: `date`" 			> $fuji_mail_textfile
	  echo "*=*Script: $fuji_progname_base" 	>> $fuji_mail_textfile
	  echo "*=*Args: $fuji_args" 			>> $fuji_mail_textfile
	  echo "*=*Node: `hostname`" 			>> $fuji_mail_textfile
	  echo "*=*User: ${USERNAME}" 			>> $fuji_mail_textfile
 	  echo "${_fuji_ERROR_STR} ${1:-virheilmoitusta ei annettu}" >> $fuji_mail_textfile	  
 	  local mail_subject="%ERROREXIT-E-Ilmoitus virhetoiminnasta koneessa `hostname`"
 	  $fuji_mail_proc -s "$mail_subject" $fuji_mail_to < $fuji_mail_textfile
  fi
  
  echo -e "${_fuji_ERROR_STR} ${1:-no error message provided}" 
  exit ${errorcode};
} # === End of fuji_error() === #
# readonly -f fuji_error

# ======================================================================
# Routine: fuji_error_multi
#   Prints the (optional) error messages in the positional arguments, one
#     per line, and then
#   Exits with the error code contained in $? if $? is non-zero, otherwise
#     exits with status 1
#   All other arguments are ignored
# Example: fuji_error_multi "missing file" "see documentation"
# NEVER RETURNS
# ======================================================================
fuji_error_multi()
{
  local errrorcode=$?
  set +x # don't trace this, but we are interested in who called
  fuji_stacktrace # we'll see the arguments in the next statement
  if ((errorcode = 0))
  then
    errorcode=1
  fi
  touch $fuji_mail_textfile
  if [ -n "$fuji_error_mail" -a "$fuji_error_mail" = "1" -a -w $fuji_mail_textfile ]
  then
	  fuji_subloppu
	  echo "*=*Date: `date`" 				> $fuji_mail_textfile
	  echo "*=*Script: $fuji_progname_base" >> $fuji_mail_textfile
	  echo "*=*Args: $fuji_args" 			>> $fuji_mail_textfile
	  echo "*=*Node: `hostname`" 			>> $fuji_mail_textfile
	  echo "*=*User: ${USERNAME}" 			>> $fuji_mail_textfile
	  while test $# -gt 1
  	  do
    	echo -e "${_fuji_ERROR_STR} ${1}"	>> $fuji_mail_textfile
    	shift
  	  done
 	  echo "${_fuji_ERROR_STR} ${1:-virheilmoitusta ei annettu}" >> $fuji_mail_textfile	  
 	  local mail_subject="%ERROREXIT-E-Ilmoitus virhetoiminnasta koneessa `hostname`"
 	  $fuji_mail_proc -s "$mail_subject" $fuji_mail_to < $fuji_mail_textfile
  fi  
  
  while test $# -gt 1
  do
    echo -e "${_fuji_ERROR_STR} ${1}"
    shift
  done
  echo -e "${_fuji_ERROR_STR} ${1:-no error message provided}"
  exit ${errorcode};
} # === End of fuji_error_multi() === #
# readonly -f fuji_error_multi

# ======================================================================
# Routine: fuji_error_no_exit
#   Prints the supplied errormessage, and propagates the $? value
# Example: fuji_error_no_exit "an error message"
# ======================================================================
fuji_error_no_exit()
{
  local errorcode=$?
  set +x # don't trace this, but we are interested in who called
  fuji_stacktrace # we'll see the arguments in the next statement
  touch $fuji_mail_textfile
  
  if [ -n "$fuji_error_mail" -a "$fuji_error_mail" = "1" -a -w $fuji_mail_textfile ]
  then
	  fuji_subloppu
	  echo "*=*Date: `date`" 				> $fuji_mail_textfile
	  echo "*=*Script: $fuji_progname_base" >> $fuji_mail_textfile
	  echo "*=*Args: $fuji_args" 			>> $fuji_mail_textfile
	  echo "*=*Node: `hostname`" 			>> $fuji_mail_textfile
	  echo "*=*User: ${USERNAME}" 			>> $fuji_mail_textfile
 	  echo "${_fuji_ERROR_STR} ${1:-virheilmoitusta ei annettu}" >> $fuji_mail_textfile	  
 	  local mail_subject="%ERROREXIT-E-Ilmoitus virhetoiminnasta koneessa `hostname`"
 	  $fuji_mail_proc -s "$mail_subject" $fuji_mail_to < $fuji_mail_textfile
  fi
  
  echo -e "${_fuji_ERROR_STR} ${1}"
  $_fuji_trace
  return $errorcode
} # === End of fuji_error_no_exit() === #
# readonly -f fuji_error_no_exit


# ======================================================================
# Routine: fuji_warning
#   Prints the supplied warning message
# Example: fuji_warning "replacing default file foo"
# ======================================================================
fuji_warning()
{
  set +x # don't trace this, but we are interested in who called
  fuji_stacktrace # we'll see the arguments in the next statement
  touch $fuji_mail_textfile
  if [ -n "$fuji_warning_mail" -a "$fuji_warning_mail" = "1" -a -w $fuji_mail_textfile ]
  then
	  echo "*=*Date: `date`" 				> $fuji_mail_textfile
	  echo "*=*Script: $fuji_progname_base" >> $fuji_mail_textfile
	  echo "*=*Args: $fuji_args" 			>> $fuji_mail_textfile
	  echo "*=*Node: `hostname`" 			>> $fuji_mail_textfile
	  echo "*=*User: ${USERNAME}" 			>> $fuji_mail_textfile
 	  echo "${_fuji_WARN_STR} ${1}" 		>> $fuji_mail_textfile	  
 	  local mail_subject="%WARNING-W-Varoitus virhetoiminnasta koneessa `hostname`"
 	  $fuji_mail_proc -s "$mail_subject" $fuji_mail_to < $fuji_mail_textfile
  fi  
  echo -e "${_fuji_WARN_STR} ${1}"
  $_fuji_trace
} # === End of fuji_warning() === #
# readonly -f fuji_warning

# ======================================================================
# Routine: fuji_inform
#   Prints the supplied informational message
# Example: fuji_inform "beginning dependency analysis..."
# ======================================================================
fuji_inform()
{
  set +x # don't trace this, but we are interested in who called
  fuji_stacktrace # we'll see the arguments in the next statement
  touch $fuji_mail_textfile  
  if [ -n "$fuji_info_mail" -a "$fuji_info_mail" = "1" -a -w $fuji_mail_textfile ]
  then
	  echo "*=*Date: `date`" 				> $fuji_mail_textfile
	  echo "*=*Script: $fuji_progname_base" >> $fuji_mail_textfile
	  echo "*=*Args: $fuji_args" 			>> $fuji_mail_textfile
	  echo "*=*Node: `hostname`" 			>> $fuji_mail_textfile
	  echo "*=*User: ${USERNAME}" 			>> $fuji_mail_textfile
 	  echo "${_fuji_INFO_STR} ${1}" 		>> $fuji_mail_textfile	  
 	  local mail_subject="%INFO-I-Ilmoitus palvelimelta `hostname`"
 	  $fuji_mail_proc -s "$mail_subject" $fuji_mail_to < $fuji_mail_textfile
  fi    
  echo -e "${_fuji_INFO_STR} ${1}"
  $_fuji_trace
} # === End of fuji_inform() === #
# readonly -f fuji_inform



# ======================================================================
# Routine: fuji_request
#   Retrieve user response to a question (in the optional argument $1)
#   Accepts only "yes" or "no", repeats until valid response
#   If fuji_auto_answer=="yes", acts as though user entered "yes"
#   If fuji_auto_answer=="no", acts as though user entered "no"
#   If "yes" then return 0 (true)
#   If "no" then return 1 (false)
# ======================================================================
fuji_request()
{
  fuji_stacktrace "${@}"
  local answer=""

  if [ "${fuji_auto_answer}" = "yes" ]
  then
    echo -e "${_fuji_QUERY_STR} $1 (yes/no) yes"
    return 0
  elif [ "${fuji_auto_answer}" = "no" ]
  then
    echo -e "${_fuji_QUERY_STR} $1 (yes/no) no"
    return 1
  fi

  while true
  do
    echo -n -e "${_fuji_QUERY_STR} $1 (yes/no) "
    if read -e answer
    then
      if [ "X${answer}" = "Xyes" ]
      then
        return 0
      fi
      if [ "X${answer}" = "Xno" ]
      then
        return 1
      fi
    else
      # user did a ^D
      echo -e "Quitting.\n"
      exit 1
    fi
  done
} # === End of fuji_request() === #
# readonly -f fuji_request

# ======================================================================
# Routine: fuji_get_value
#   Get a verified non-empty string in variable "fuji_value"
#   Prompt with the first argument.
#   The 2nd argument if not empty must be -s. (for "silent" password
#     entry)
# NO AUTOANSWER SUPPORT.
# SETS GLOBAL VARIABLE: fuji_value
# ======================================================================
fuji_get_value()
{
  fuji_stacktrace "${@}"
  local value
  local verify
  while true
  do
    echo -n -e "${_fuji_QUERY_STR} "
    if read $2 -p "$1 " value 
    then
      [ -n "$2" ] && echo 
      if [ -n "${value}" ]
      then
        echo -n -e "${_fuji_QUERY_STR} "
        read $2 -p "Anna toisen kerran: " verify
        [ -n "$2" ] && echo
        [ "${verify}" = "${value}" ] && break
      fi
    else
      # user did a ^D
      echo -e "Quitting.\n"
      exit 1
    fi
  done
  echo
  fuji_value="${value}"
  return 0
} # === End of fuji_get_value() === #
# readonly -f fuji_get_value




# ======================================================================
# Routine: fuji_trace_on
#   turns on shell tracing of csih functions
# ======================================================================
fuji_trace_on()
{
  if [ $VFY_ALL -eq "1" -o $VFY_ALL -eq "3" ]
  then
  	_fuji_trace='set -x'
  	trap 'fuji_stacktrace "returning with" $?; set -x' RETURN
  	set -T
  else
    _fuji_trace='set +x'
    set +T
  fi  
  fuji_stacktrace "${@}"
} # === End of fuji_trace_on() === #
# readonly -f fuji_trace_on


# ======================================================================
# Routine: fuji_trace_off
#   turns off shell tracing of csih functions
# ======================================================================
fuji_trace_off()
{
  trap '' RETURN
  fuji_stacktrace "${@}"
  _fuji_trace=
  set +x
  set +T
} # === End of fuji_trace_off() === #
# readonly -f fuji_trace_off


# ======================================================================
# Routine: fuji_stacktrace
# ======================================================================
fuji_stacktrace()
{
  set +x # don't trace this!
  local -i n=$(( ${#FUNCNAME} - 1 ))
  local val=""
  # if [ -n "$_fuji_trace" -a "$VFY_ALL" -gt "1" ]  
  if [ -n "$_fuji_trace" -a -n "$VFY_ALL" ]
  then
  	if [ "$VFY_ALL" -gt "1" ]
  	then
	    while [ $n -gt 0 ]
	    do
	      if [ -n "${FUNCNAME[$n]}" ]
	      then
	        if [ -z "$val" ]
	        then
	          val="${FUNCNAME[$n]}[${BASH_LINENO[$(($n-1))]}]"
	        else
	          val="${val}->${FUNCNAME[$n]}[${BASH_LINENO[$(($n-1))]}]"
	        fi
	      fi
	    n=$(($n-1))
	    done
	    echo -e "${_fuji_STACKTRACE_STR} ${val} ${@}"
    fi
  fi
} # === End of fuji_stacktrace() === #
# readonly -f fuji_stacktrace


# ======================================================================
# Routine: fuji_proginfo
# ======================================================================
fuji_proginfo() 
{
    cat - <<EOF
Copyright (C) 2011 Fujitsu Finland.
EOF
} # === End of fuji_proginfo() === #
# readonly -f fuji_proginfo

##-----------------------------------------------------------------------------
# Seuraava muuttuja VFY_ALL vaikuttaa siihen miten skriptia debugataan.
# - jos muuttuja puuttuu, sen arvo = 0 (nolla), tai tyhja, ei debuggausta, 
#	eik‰ suorituspinoa (stacktrace)
# - jos muuttujan arvo = 1, tulostetaan pelkka debuggaus
# - jos muuttujan arvo = 2, tulostetaan pelkka suorituspino
# - jos muuttujan arvo = 3, tulostetaan sek‰ debuggaus, ett‰ suorituspino
#
##-----------------------------------------------------------------------------
if [ -n "$VFY_ALL" ]
then
	fuji_trace_on
fi

##----------------------------------------------------------------------------
## Seuraavassa halytysten kasittelyssa kaytettyja yleisia rutiineita
##-----------------------------------------------------------------------------

#==============================================================================
#
# Funktio: chk_if_print_message:
#
#       Funktiolla tutkitaan josko virheimoitus on jo tulostettu -> ei toisteta
#       tiettyyn aikaan (esim. seuraavan 6h sisalla).
#
# Paluuarvo:
#       true/false
#
#==============================================================================
chk_if_print_message()
{
  # Aina kun tullaan tahan ollan joku halyraja ylitetty,
  # muutetaan siis statustietoa
  set_alarm_status "yes"
  # Jos tiedostossa oli jo virhetieto ei kirjoiteta paalle,
  # muutetaan ainoastaan aikaleima
  if [ -f $patrol_file ]
  then
    read -r firstline < $patrol_file
    firstmark=$(echo $firstline | awk '{print $1}')
    if [ $firstmark -ne 1 ]
    then
      echo "1" > $patrol_file
    else
      touch $patrol_file
    fi
  else
    echo "1" > $patrol_file
  fi

  # mahdollisesti monia lipputiedostoja (yleensa kylla jonkin virhetilanteen
  # seurauksena), kelataan kaikki lapi, otetaan viimeisin kiinni
  for file in $(ls -ltr ${flag_file}.${1}.* 2>/dev/null| awk '{print $9}')
  do
    old_flag_file=$file
  done
  # Oletuksena palautetaan false (=1)
  return_code=1
  if [ -z $old_flag_file ]
  then
    # Ellei lipputiedostoa loydy luodaan se
    touch ${flag_file}.${1}.${my_seconds}
    return_code=0
  else
    # Jos loytyi tutkitaan ollaanko uuden viestin aikaraja ylitetty
    start_time=$(echo $old_flag_file | awk -F "." '{print $3}')
    end_time=$my_seconds
    fuji_duration $start_time $end_time
    alarm_age=$fuji_value
    # Ei tehda (ainaakaan viela tassa versiossa) uutta halya samasta aiheesta
    # repeat_alarm_age=$(cat ${WORKING_DIR}/bin/alarmdefs | grep "${my_progname}_age" | awk -F "=" '{print $2}')
    # if [ $alarm_age -ge $repeat_alarm_age ]
    # then
    # # Jos haly tulostettu riittavan kauan aikaa sitten, tulostetaan uusi
    #   rm -rf ${flag_file}.*
    #   touch ${flag_file}.${1}.${my_seconds}
    #   return_code=0  
    # fi
  fi
  return $return_code

} # === End of chk_if_print_message() === #
# readonly -f chk_if_print_message

#==============================================================================
#
# Funktio: chk_if_print_pgpool_message:
#
#       Funktiolla tutkitaan josko virheimoitus on jo tulostettu -> ei toisteta
#       tiettyyn aikaan (esim. seuraavan 6h sisalla).
#
# Paluuarvo:
#       true/false
#
#==============================================================================
chk_if_print_pgpool_message()
{
  # Aina kun tullaan tahan ollan joku halyraja ylitetty,
  # muutetaan siis statustietoa
  set_alarm_status "yes"
  # Jos tiedostossa oli jo virhetieto ei kirjoiteta paalle,
  # muutetaan ainoastaan aikaleima
  if [ -f $patrol_file ]
  then
    read -r firstline < $patrol_file
    firstmark=$(echo $firstline | awk '{print $1}')
    # if [ $firstmark -ne 1 ]
    # then
    #   echo "$firstmark" > $patrol_file
    # else
    touch $patrol_file
    # fi
  else
    echo "1" > $patrol_file
  fi

  # mahdollisesti monia lipputiedostoja (yleensa kylla jonkin virhetilanteen
  # seurauksena), kelataan kaikki lapi, otetaan viimeisin kiinni
  for file in $(ls -ltr ${flag_file}.${1}.* 2>/dev/null| awk '{print $9}')
  do
    old_flag_file=$file
  done
  # Oletuksena palautetaan false (=1)
  return_code=1
  if [ -z $old_flag_file ]
  then
    # Ellei lipputiedostoa loydy luodaan se
    touch ${flag_file}.${1}.${my_seconds}
    return_code=0
  else
    # Jos loytyi tutkitaan ollaanko uuden viestin aikaraja ylitetty
    start_time=$(echo $old_flag_file | awk -F "." '{print $3}')
    end_time=$my_seconds
    fuji_duration $start_time $end_time
    alarm_age=$fuji_value
    # Ei tehda (ainaakaan viela tassa versiossa) uutta halya samasta aiheesta
    # repeat_alarm_age=$(cat ${WORKING_DIR}/bin/alarmdefs | grep "${my_progname}_age" | awk -F "=" '{print $2}')
    # if [ $alarm_age -ge $repeat_alarm_age ]
    # then
    # # Jos haly tulostettu riittavan kauan aikaa sitten, tulostetaan uusi
    #   rm -rf ${flag_file}.*
    #   touch ${flag_file}.${1}.${my_seconds}
    #   return_code=0
    # fi
  fi
  return $return_code

} # === End of chk_if_print_pgpool_message() === #
# readonly -f chk_if_print_pgpool_message

#==============================================================================
#
# Funktio: set_alarm_status:
#
#       Funktiolla asetetaan tarkistuskierroksen status
#
# Parametrit:
#       $1             status (no=ei halyrajan ylityksia/yes=halyraja ylitetty) 
#
# Paluuarvo:
#       none 
#
#==============================================================================
set_alarm_status()
{
  echo "$1" > ${flag_file}_alarm.status
} # === End of rm_old_flag_files() === #
# readonly -f set_alarm_status

#==============================================================================
#
# Funktio: rm_old_flag_files
#
#       Funktiolla poistetaan turhat, vanhat lipputiedostot
#
# Paluuarvo:
#       none
#
#==============================================================================
rm_old_flag_files()
{
  status=$(cat ${flag_file}_alarm.status)
  case "$status" in
    "no" | "NO")
	# Halyrajaa ei ylitetty, poistetaan mahdolliset vanhat liput
	rm -rf ${flag_file}.*
	rm -rf ${flag_file}_alarm.status
        echo "0" > $patrol_file
	;;
    "yes" | "YES")
	# Halyraja ylitettiin, ei poisteta lippuja (ainoastaan statustieto) 
	rm -rf ${flag_file}_alarm.status
	;;
    *)
	# Statuksesta ei tietoa, oletetaan etta ei ylitetty
	rm -rf ${flag_file}.*
	rm -rf ${flag_file}_alarm.status
        echo "0" > $patrol_file
	;;
  esac
} # === End of rm_old_flag_files() === #
# readonly -f rm_old_flag_files

#==============================================================================
#
# Funktio: chk_if_running:
#
#       Funktiolla tutkitaan jos rutiini on jo ajossa
#
# Parametrit:
#       
#
# Paluuarvo:
#      true/false 
#
#==============================================================================
chk_if_running()
{
#   pgrep -lf ".[ /]$fuji_progname_base( |\$)" > /tmp/my_tmp.${fuji_progname_base}
#   cat  /tmp/my_tmp.${fuji_progname_base} 
#   result=$(cat  /tmp/my_tmp.${fuji_progname_base} | wc -l)
#   rm -rf /tmp/my_tmp.${fuji_progname_base}
  result=1
  PIDFILE=${WORKING_DIR}/tmp/${fuji_progname_base}.pid
  if [ -f $PIDFILE ]
  then
    PID=$(cat $PIDFILE)
    ps -p $PID > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
      my_res=$(ps -ef | grep -v grep | grep $fuji_progname_base | grep $PID | wc -l)
      if [ $my_res -gt 0 ]
      then
        echo "WARNING: Job is already running"
        result=2
      fi
    else
      ## Process not found assume not running
      echo $$ > $PIDFILE
      if [ $? -ne 0 ]
      then
        echo "ERROR: Could not create PID file"
        result=9 
      fi
    fi
  else
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "ERROR: Could not create PID file"
      result=9 
    fi
  fi
  return $result
} # === End of chk_if_running() === #
# readonly -f chk_if_running




#==============================================================================
#
# Funktio: chk_if_pg_is_in_recovery:
#
#       Funktiolla tutkitaan onko kanta recovery moodissa (standby)j
##
# Paluuarvo:
#       0=true/1=false
#
#==============================================================================
chk_if_pg_is_in_recovery() 
{
  local IN_RECOVERY=$(psql -d fuji_dba_db -t -c 'SELECT pg_is_in_recovery()')
  case ${IN_RECOVERY// /} in
  ( t ) return 0 ;;
  ( f ) return 1 ;;
  esac
}

# Yleisia alustuksia
fuji_get_seconds
my_seconds=$fuji_value
if [ -z $PG_SID ] && [ -z $PGPOOL_SID ]
then
  my_sid=""
else
  my_sid=$(echo ".${PG_SID}${PGPOOL_SID}")
fi
my_progname=$(echo $fuji_progname_base | awk -F "." '{print $1}')
my_progname=$(echo "${my_progname}${my_sid}")
flag_file=${WORKING_DIR}/tmp/${my_progname}
tmp_progname=$(echo $my_progname | sed "s/fuji_/dba_/")
patrol_file=${WORKING_DIR}/iclcheck/${tmp_progname}

# Asetataan status, oletetaan etta uusia halyja ei tule
# (tata kaytetaan lipputietojen siivouksessa)
set_alarm_status "no"





