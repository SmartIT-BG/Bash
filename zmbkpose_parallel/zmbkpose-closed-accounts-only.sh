#!/bin/bash

# admin@smartit.bg

LDAPHOST="10.10.10.10"
LDAPPASS="password"

LOG_FILE="/mnt/zimbra_backup/$(date +"%m-%d-%y")-backup-log.log"

# Active accounts in the zimbra server
ACCOUNTS_FILE="/mnt/zimbra_backup/zimbra-active-accounts.txt"

# Running file keeps information if another instance 
# of this script is working on the same directory
RUNNING_FILE="/mnt/zimbra_backup/running.txt"

# zmbkpose script location
ZMBKPOSE_SCRIPT=/home/smartitbg/zmbkpose/zmbkpose-closed.sh

# PARALLEL PROCESSING
#
# zmbkpose do parallel backups independently, even with -a switch;
# Current script is passing to zmbkpose five accounts at once with -a switch;
# But it needs to wait the "haviest" account to be backed up to continue with the next five accounts;
# To fastening the process this script will run zmbkpose with -a switch N number of times in background, 
# which option is configurable with next variables.

# Zmbkpose parallel accounts (see zmbkpose.conf)
PARALLEL_ACCOUNTS_ZMB=5
# Max number of accounts that will be backed up at any given time
PARALLEL_ACCOUNTS=$((PARALLEL_ACCOUNTS_ZMB * 4))


if [ -z $1 ]; then
  echo "Missing arguments. Usage:"
  echo
  echo "-f Full backup"
  echo "-i Incremental backup"

  exit 1

fi

# if running file not exists - create it
if [ ! -f $RUNNING_FILE ]; then
  echo -n "no" > $RUNNING_FILE

fi

RUNNING=$(cat $RUNNING_FILE)

# exit if another backup is in progress
if [ $RUNNING == "yes" ]; then
  echo "ERROR: Another instance of script is active"
  exit 1

fi

# Check for ldapsearch existens
ldapsearch -VV &> /dev/null

if [ $? -ne 0 ]; then
  echo "ERROR: ldapsearch does not exists."
  exit 1

fi

# Get Zimbra Active accounts
ldapsearch -x -D "cn=config" -w $LDAPPASS -h $LDAPHOST '(&(zimbraAccountStatus=Closed))' 2> /dev/null | grep "mail:" | awk '{print $2}' > $ACCOUNTS_FILE

# check first line for valid email address
if [ -f $ACCOUNTS_FILE ]; then
  head -n 1 $ACCOUNTS_FILE | egrep "\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b" > /dev/null

  if [ $? -ne 0 ]; then
    echo "ERROR: $ACCOUNTS_FILE does not contains vlaid email address."
    echo "Check your ldap search filter or your ldap credentials"
    exit 1

  fi
  
else
  echo "ERROR: $ACCOUNTS_FILE does not exists."
  exit 1
 
fi

NUM_OF_ACCOUNTS=$(wc -l < $ACCOUNTS_FILE)


echo "Backup of $LDAPHOST is about to begin"
echo

GROUP_ACCOUNTS=0
FIRST_ACCOUNT=1
CAT_ACCOUNTS=""

# main loop
#
COUNTER=0
OVERALL_COUNTER=0
while read account; do

  COUNTER=$((COUNTER+1))
  OVERALL_COUNTER=$((OVERALL_COUNTER+1))

  if [ $FIRST_ACCOUNT -eq 1 ]; then
    CAT_ACCOUNTS=$account
    FIRST_ACCOUNT=0
  
  else
    CAT_ACCOUNTS="$CAT_ACCOUNTS"','"$account"

  fi

  if [ $COUNTER -eq 5 -o $OVERALL_COUNTER -eq $NUM_OF_ACCOUNTS ]; then
    # Run Zmbkpose on background
    $ZMBKPOSE_SCRIPT $1 -a $CAT_ACCOUNTS &>> $LOG_FILE &
    # timing
    sleep 4

    while true
    do

      # get current active backups
      CURRENT_ACTIVE_BACKUPS=$(ps aux | grep $ZMBKPOSE_SCRIPT | wc -l)
      # exclude grep process from counter
      CURRENT_ACTIVE_BACKUPS=$((CURRENT_ACTIVE_BACKUPS - 1))

      if [ $CURRENT_ACTIVE_BACKUPS -le $(($PARALLEL_ACCOUNTS - $PARALLEL_ACCOUNTS_ZMB)) ]; then
	    #echo "Current active accounts: $CURRENT_ACTIVE_BACKUPS"
	    echo "Backup accounts: $CAT_ACCOUNTS"

        break
      
      else
	    echo "No more slots for parallel execution. Sleeping for 20s..."
        sleep 20

      fi

    done

    COUNTER=0
    FIRST_ACCOUNT=1

  fi

done <$ACCOUNTS_FILE

# backup is ready
echo -n "no" > $RUNNING_FILE
