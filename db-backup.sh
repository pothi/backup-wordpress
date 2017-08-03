#!/bin/bash

# version - 1.1.1

### Variables - Please do not add trailing slash in the PATHs

# if you'd like to enable offsite backup...
# run 'pip install aws'
# aws configure

SCRIPT_NAME=db-backup.sh

LOG_FILE=${HOME}/log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

# You may hard-code the domain name and AWS S3 Bucket Name here
DOMAIN=
BUCKET_NAME=

# path to wp-config.php file
# WP_CONFIG_PATH=${HOME}/public_html/wp-config.php

# where to store the backups?
BACKUP_PATH=${HOME}/Backup/databases

WP_CLI=/usr/local/bin/wp
PUBLIC_DIR=public

#-------- Do NOT Edit Below This Line --------#

CURRENT_DATE_TIME=$(date +%F_%H-%M-%S)

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo 'Log directory not found'
    echo "Please create it manually at $HOME/log and then re-run this script"
    exit 1
fi 

# create the dir to keep backups, if not exists
# mkdir -p $BACKUP_PATH &> /dev/null
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo "BACKUP_PATH is not found at $BACKUP_PATH"
	echo 'You may create it manually and then re-run this script'
	exit 1
fi

# get environment variables
if [ -f "$HOME/.my.exports"  ]; then
    source ~/.my.exports
fi
if [ -f "$HOME/.envrc"  ]; then
    source ~/.envrc
fi
if [ -f "$HOME/.env"  ]; then
    source ~/.env
fi

# check for the variable/s in three places
# 1 - hard-coded value
# 2 - optional parameter while invoking the script
# 3 - environment files

if [ "$DOMAIN" == ""  ]; then
    if [ "$1" == "" ]; then
        if [ "$WP_DOMAIN" != "" ]; then
            DOMAIN=$WP_DOMAIN
        else
            echo 'Usage ${SCRIPT_NAME} example.com (S3 bucket name)'; exit 1
        fi
    else
        DOMAIN=$1
    fi
fi

if [ "$BUCKET_NAME" == ""  ]; then
    if [ "$2" != "" ]; then
        BUCKET_NAME=$2
    elif [ "$AWS_S3_BUCKET_NAME" != "" ]; then
        BUCKET_NAME=$AWS_S3_BUCKET_NAME
    fi
fi

SITE_PATH=${HOME}/sites/$DOMAIN
if [ ! -d "$SITE_PATH" ]; then
	echo; echo 'Site is not found at '$SITE_PATH; echo "Usage ${SCRIPT_NAME} domainname.tld (S3 bucket name)"; echo;
	exit 1
fi

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
DOMAIN_FULL_PATH=$(echo $DOMAIN | awk '{gsub(/\//,"_")}; 1')

OUTPUT_FILE_NAME=${SITE_PATH}/db-${DOMAIN_FULL_PATH}-${CURRENT_DATE_TIME}.sql.gz

# if exists, move the existing backup from $SITE_PATH to $BACKUP_PATH
# then store the new backup to $SITE_PATH
# to be taken as a backup by files-backup.sh script
mv $SITE_PATH/db-${DOMAIN_FULL_PATH}-[[:digit:]-_]*.sql.gz ${BACKUP_PATH}/ &> /dev/null

# take actual DB backup
if [ -f "$WP_CLI" ]; then
    $WP_CLI --path=${SITE_PATH}/${PUBLIC_DIR} db export - | gzip > $OUTPUT_FILE_NAME
else
    echo 'Please install wp-cli and re-run this script'; exit 1;
fi

# external backup
if [ "$BUCKET_NAME" != "" ]; then
	if [ ! -e "/usr/local/bin/aws" ] ; then
		echo; echo 'Did you run "pip install aws && aws configure"'; echo;
	fi

    /usr/local/bin/aws s3 cp ${SITE_PATH}/db-${DOMAIN_FULL_PATH}-${CURRENT_DATE_TIME}.sql.gz s3://$BUCKET_NAME/${DOMAIN_FULL_PATH}/backups/databases/
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking offsite backup';
		echo "Check $LOG_FILE for any log info"; echo
    else
        echo; echo 'Offsite backup successful'; echo
    fi
fi

# Delete backups that are two months older
MONTHSAGO=$(expr $(date +%-m) - 2)
case $MONTHSAGO in
-1)
	rm -f ${BACKUP_PATH}/db-${DOMAIN}-$(expr $(date +%Y) - 1)-11-*.sql.gz &> /dev/null
	;;
0)
	rm -f ${BACKUP_PATH}/db-${DOMAIN}-$(expr $(date +%Y) - 1)-12-*.sql.gz &> /dev/null
	;;
*)
	rm -f ${BACKUP_PATH}/db-${DOMAIN}-$(date +%Y)-0$MONTHSAGO-*.sql.gz &> /dev/null
	;;
10)
	rm -f ${BACKUP_PATH}/db-${DOMAIN}-$(date +%Y)-10-*.sql.gz &> /dev/null
	;;
esac

echo; echo 'DB backup done; please check the latest backup at '${SITE_PATH}' and the older backups at '${BACKUP_PATH}'.'; echo
