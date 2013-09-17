#!/bin/bash
# minebackup was built to backup Minecraft servers using rdiff-backup 
# Copyright (C) 2013 Jonas Friedmann - License: Attribution-NonCommercial-ShareAlike 3.0 Unported
# Based on Natenom's mcontrol (https://github.com/Natenom/mcontrol)

#####
# Settings
#####

# Binary names
BIN_RDIFF="rdiff-backup"
BIN_TAR="tar"
BIN_NICE="nice"
BIN_IONICE="ionice"

# nice and ionice settings
RUNBACKUP_NICE="${BIN_NICE} -n19"
RUNBACKUP_IONICE="${BIN_IONICE} -c 3"

# Messages
SAY_BACKUP_START="Backup started..."
SAY_BACKUP_FINISHED="Backup successfully finished."

#####
# DO NOT EDIT BELOW
#####

# Read user settings from ~/.minebackup.conf
SETTINGS_FILE="$HOME/.minebackup.conf"

# Check if $SETTINGS_FILE exist
if [ -f $SETTINGS_FILE ]
then
  . "${SETTINGS_FILE}"
else
  # Create default one
  echo "[INFO] Creating default configuration file $SETTINGS_FILE"
  cat > $SETTINGS_FILE << EOCONF
# Screen session name
SCREENNAME="minecraft"
# Display name of your server
SERVERNAME="Minecraft Server"
# Server root directory
SERVERDIR="/opt/minecraft"
# Backup directory
BACKUPDIR="/opt/backups/minecraft"
# Filename for full backup (using tar)
FULLBACKUP="/opt/backups/minecraft.tar.gz"
# Quota for backup directory
BACKUP_QUOTA_MiB=5000

# Exclude the following files/directories in backups
RDIFF_EXCLUDES=(server.log plugins/dynmap/web/tiles/)

## Overridable configurations (remove "#" to activate)
#RUNBACKUP_NICE="${BIN_NICE} -n19"
#RUNBACKUP_IONICE="${BIN_IONICE} -c 3"

#SAY_BACKUP_START="Backup started..."
#SAY_BACKUP_FINISHED="Backup successfully finished."
EOCONF
fi

# Check if binaries exist
BINS=( "${BIN_RDIFF} ${BIN_TAR} ${BIN_NICE} ${BIN_IONICE}" )
for BIN in $BINS;
do
  type -P $BIN &>/dev/null && continue || echo "'$BIN not found! Run 'apt-get install $BIN' to fix this"; exit 1
done

# Check if $BACKUPDIR exist
if [ ! -d $BACKUPDIR ]
then
  echo "'$BACKUPDIR' doesn't exist. Run the following commands as root:"
  echo "<!--"
  echo "mkdir -p $BACKUPDIR"
  echo "chown -R $USER $BACKUPDIR"
  echo "-->"
  exit 1
fi

# Check quota
function trim_to_quota() {
  [ ${DODEBUG} -eq 1 ] && set -x
  local quota=$1
  local _backup_dir="${BACKUPDIR}"
  _size_of_all_backups=$(($(du -s ${_backup_dir} | cut -f1)/1024))

  while [ ${_size_of_all_backups} -gt $quota ];
  do
    echo ""
    echo "Total backup size of ${_size_of_all_backups} MiB has reached quota of $quota MiB."
    local _increment_count=$(($(${BIN_RDIFF} --list-increments ${_backup_dir}| grep -o increments\. | wc -l)-1))
    echo "  going to --force --remove-older-than $((${_increment_count}-1))B"
    ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_RDIFF} --force --remove-older-than $((${_increment_count}-1))B "${BACKUPDIR}" >/dev/null 2>&1
    echo "  Removed."
    _size_of_all_backups=$(($(du -s ${_backup_dir} | cut -f1)/1024))
  done
  echo "Total backup size (${_size_of_all_backups} MiB) <= ($quota MiB)... done"
}

# 'Check executive user' function
function as_user() {
  [ ${DODEBUG} -eq 1 ] && set -x
  if [ "$(whoami)" = "${USER}" ] ; then
    /bin/bash -c "$1" 
  else
    su - ${RUNAS} -c "$1"
  fi
}

# 'Check running process' function
function is_running() {
  [ ${DODEBUG} -eq 1 ] && set -x
  if ps aux | grep -v grep | grep SCREEN | grep "${SCREENNAME} " >/dev/null 2>&1
  then
    return 0 
  else
    return 1
  fi
}

# 'Disable ingame saving' function
function mc_saveoff() {
    [ ${DODEBUG} -eq 1 ] && set -x
  if is_running
  then
    echo -ne "${SERVERNAME} is running, suspending saves... "
    as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"say ${SAY_BACKUP_START}\"\015'"
    as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"save-off\"\015'"
    as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"save-all\"\015'"
    sync
    sleep 10
    echo -ne "done\n"
  else
    echo "${SERVERNAME} was not running... done"
  fi
}

# 'Enable ingame saving' function
function mc_saveon() {
        [ ${DODEBUG} -eq 1 ] && set -x
  if is_running
  then
    echo -ne "${SERVERNAME} is running, re-enabling saves... "
    as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"save-on\"\015'"
    as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"say ${SAY_BACKUP_FINISHED}\"\015'"
    echo -ne "done\n"
  else
    echo "${SERVERNAME} was not running. Not resuming saves... done"
  fi
}

# Backup function
function mc_backup() {
  [ ${DODEBUG} -eq 1 ] && set -x

  # Full backup (tar)!
  if [[ ${1} == "full" ]]; then

    # Build exclude string
    local _tarexcludes=""
    for i in ${RDIFF_EXCLUDES[@]}
    do
      _tarexcludes="$_tarexcludes --exclude ${SERVERDIR}/$i"
    done

    # Check if permissions are okay
    echo -ne "Check for correct permissions ..."
    touchtest=$((touch $FULLBACKUP) >/dev/null 2>&1)
    touchstatus=$?
    [ $touchstatus -eq 0 ] && echo -ne "done\n" && rm $FULLBACKUP
    [ $touchstatus -ne 0 ] && echo -ne "failed\n> ${touchtest}\n" && exit

    echo -ne "Full backup '${FULLBACKUP}' ..."
    ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_TAR} czf ${FULLBACKUP} ${SERVERDIR} ${_tarexcludes} >/dev/null 2>&1
    echo -ne "done\n"
    exit 1
  fi

  [ -d "${BACKUPDIR}" ] || mkdir -p "${BACKUPDIR}"
  echo -ne "Backing up ${SCREENNAME}... "

  if [ -z "$(ls -A ${SERVERDIR})" ];
  then
    echo -ne "failed\n"
    echo -ne "=> Something must be wrong, SERVERDIR(\"${SERVERDIR}\") is empty.\nWon't do a backup.\n"
    exit 1
  fi

  local _excludes=""
  for i in ${RDIFF_EXCLUDES[@]}
  do
    _excludes="$_excludes --exclude ${SERVERDIR}/$i"
  done
  ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_RDIFF} ${_excludes} "${SERVERDIR}" "${BACKUPDIR}"
  echo -ne "done\n"

  trim_to_quota ${BACKUP_QUOTA_MiB} 
}

# 'List available backups' function
function listbackups() {
  [ ${DODEBUG} -eq 1 ] && set -x

  temptest=`${BIN_RDIFF} -l "${BACKUPDIR}" &>/dev/null`
  tempstatus=$?

  if [ $tempstatus -eq 0 ]
  then
    echo "Backups for server \"${SERVERNAME}\""
    [ ${DODEBUG} -eq 1 ] && ${BIN_RDIFF} -l "${BACKUPDIR}"
    ${BIN_RDIFF} --list-increment-sizes "${BACKUPDIR}"
  else
    echo "Apparently no backups available"
  fi
}

# 'Restore to x' function
function restore() {
  [ ${DODEBUG} -eq 1 ] && set -x

  # Check for argument
  echo -ne "Check for valid argument ... "
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    echo -ne "done\n";
    arg="${1}m"
  elif [[ "$1" == "now" ]]; then
    echo -ne "done\n";
    arg="${1}"
  else
    echo -ne "failed\n";
    echo -ne "=> Make sure your argument contains only numbers.\n"
    exit 1
  fi

  # Check for running server
  echo -ne "Check if '${SERVERNAME}' is not running... "
  if is_running
  then
    echo -ne "failed\n"
    echo "=> Make sure to shutdown your server before you start to restore."
    exit 1
  fi

  echo -ne "done\n"

  echo -ne "Starting to restore '${arg}' ... "
  rdiffstatus=$((rdiff-backup --restore-as-of ${arg} --force $BACKUPDIR $SERVERDIR) 2>&1)
  tempstatus=$?
  [ $tempstatus -eq 0 ] && echo -ne "successful\n"
  [ $tempstatus -ne 0 ] && echo -ne "failed\n> ${rdiffstatus}\n"
}

# 'List installed crons' function
function listcrons() {
  [ ${DODEBUG} -eq 1 ] && set -x
  crontab -l | grep "minebackup"
}

#####
# Catch argument
#####

echo "$@" > /dev/null 2>&1 
if [ "$_" = '-debug' ];
then
    DODEBUG=1
else
    DODEBUG=0
fi
#Start-Stop here
case "${1}" in
  listbackups)
    listbackups
    ;;
  backup)
    mc_saveoff
    mc_backup "${2}"
    mc_saveon
    ;;
  restore)
    restore "${2}"
    ;;
  crons)
    listcrons
    ;;
  *)cat << EOHELP
Usage: ${0} COMMAND [ARGUMENT]

COMMANDS
    backup [full]             Backup the server.
    listbackups               List current incremental backups.
    restore [<MINUTES>/now]   Restore to snapshot which is [MINUTES] ago. ("now" for the latest)
    crons                     List configured cronjobs.
    -debug                    Enable debug output (Must be the last argument).
EOHELP
    exit 1
  ;;
esac

exit 0