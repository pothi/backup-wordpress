#!/bin/bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

# version - 5.2.1

### Variables - Please do not add trailing slash in the PATHs

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/db-backups
ENCRYPTED_BACKUP_PATH=${HOME}/backups/encrypted-db-backups

# the script assumes your sites are stored like ~/sites/example.com/public, ~/sites/example.net/public, ~/sites/example.org/public and so on.
# if you have a different pattern, such as ~/app/example.com/public, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

# if WP is in a sub-directory, please leave this empty!
PUBLIC_DIR=public

# a passphrase for encryption, in order to being able to use almost any special characters use ""
PASSPHRASE=

# auto delete older backups after certain number days - default 60. YMMV
AUTODELETEAFTER=30

# You may hard-code the domain name
DOMAIN=

# AWS Variable can be hard-coded here
AWS_S3_BUCKET_NAME=

#-------- Do NOT Edit Below This Line --------#

# to capture non-zero exit code in the pipeline
set -o pipefail

# attempt to create log directory if it doesn't exist
[ -d "${HOME}/log" ] || mkdir -p ${HOME}/log
if [ "$?" -ne "0" ]; then
    echo "Log directory not found at ~/log. This script can't create it, either!"
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# attempt to create the backups directory, if it doesn't exist
[ -d "$BACKUP_PATH" ] || mkdir -p $BACKUP_PATH
if [ "$?" -ne "0" ]; then
    echo "BACKUP_PATH is not found at $BACKUP_PATH. This script can't create it, either!"
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# if passphrase is supplied, attempt to create backups directory for encrypt backups, if it doesn't exist
if [ -n "$PASSPHRASE" ]; then
    [ -d "$ENCRYPTED_BACKUP_PATH" ] || mkdir -p $ENCRYPTED_BACKUP_PATH
    if [ "$?" -ne "0" ]; then
        echo "ENCRYPTED_BACKUP_PATH Is not found at $ENCRYPTED_BACKUP_PATH. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

log_file=${HOME}/log/backups.log
exec > >(tee -a ${log_file} )
exec 2> >(tee -a ${log_file} >&2)

export PATH=~/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

declare -r script_name=$(basename "$0")
declare -r timestamp=$(date +%F_%H-%M-%S)
declare -r wp_cli=`which wp`
declare -r aws_cli=`which aws`

if [ -z "$wp_cli" ]; then
    echo "wp-cli is not found in $PATH. Exiting."
    exit 1
fi

if [ -z "$aws_cli" ]; then
    echo "aws-cli is not found in $PATH. Exiting."
    exit 1
fi

cPanel=$(/usr/local/cpanel/cpanel -V 2>/dev/null)
if [ ! -z "$cPanel" ]; then
    SITES_PATH=$HOME
    PUBLIC_DIR=public_html
fi

echo "'$script_name' started on... $(date +%c)"

let AUTODELETEAFTER--

# get environment variables, if exists
[ -f "$HOME/.envrc" ] && source ~/.envrc
[ -f "$HOME/.env" ] && source ~/.env

# check for the variable/s in three places
# 1 - hard-coded value
# 2 - optional parameter while invoking the script
# 3 - environment files

if [ "$DOMAIN" == ""  ]; then
    if [ "$1" == "" ]; then
        if [ "$WP_DOMAIN" != "" ]; then
            DOMAIN=$WP_DOMAIN
        else
            echo "Usage $script_name example.com (S3 bucket name)"; exit 1
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

# WordPress root
WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
# For cPanel - main site
[ ! -d "$WP_PATH" ] && WP_PATH=${SITES_PATH}/${PUBLIC_DIR}
[ ! -d "$WP_PATH" ] && echo "WordPress is not found at $WP_PATH" &&  exit 1

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
DOMAIN_FULL_PATH=$(echo $DOMAIN | awk '{gsub(/\//,"-")}; 1')

DB_OUTPUT_FILE_NAME=${BACKUP_PATH}/${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
ENCRYPTED_DB_OUTPUT_FILE_NAME=${ENCRYPTED_BACKUP_PATH}/${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
DB_LATEST_FILE_NAME=${BACKUP_PATH}/${DOMAIN_FULL_PATH}-latest.sql.gz

# take actual DB backup
if [ -f "$wp_cli" ]; then
    $wp_cli --path=${WP_PATH} transient delete --all
    $wp_cli --path=${WP_PATH} db export --no-tablespaces=true --add-drop-table - | gzip > $DB_OUTPUT_FILE_NAME
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking local backup!'
        [ -f $DB_OUTPUT_FILE_NAME ] && rm -f $DB_OUTPUT_FILE_NAME
    fi

    [ -L $DB_LATEST_FILE_NAME ] && rm $DB_LATEST_FILE_NAME
    if [ -n "$PASSPHRASE" ] ; then
        gpg --symmetric --passphrase $PASSPHRASE --batch -o ${ENCRYPTED_DB_OUTPUT_FILE_NAME} $DB_OUTPUT_FILE_NAME
        [ -f $DB_OUTPUT_FILE_NAME ] && rm -f $DB_OUTPUT_FILE_NAME
        ln -s $ENCRYPTED_DB_OUTPUT_FILE_NAME $DB_LATEST_FILE_NAME
    else
        ln -s $DB_OUTPUT_FILE_NAME $DB_LATEST_FILE_NAME
    fi
else
    echo 'Please install wp-cli and re-run this script'; exit 1;
fi

# external backup
if [ "$BUCKET_NAME" != "" ]; then
    if [ -z "$PASSPHRASE" ] ; then
        $aws_cli s3 cp $DB_OUTPUT_FILE_NAME s3://$BUCKET_NAME/${DOMAIN_FULL_PATH}/db-backups/ --only-show-errors
    else
        $aws_cli s3 cp $ENCRYPTED_DB_OUTPUT_FILE_NAME s3://$BUCKET_NAME/${DOMAIN_FULL_PATH}/encrypted-db-backups/ --only-show-errors
    fi
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking offsite backup';
        echo "Check $LOG_FILE for any log info"; echo
    else
        echo; echo 'Offsite backup successful'; echo
    fi
fi

# Auto delete backups 
[ -d "$BACKUP_PATH" ] && find $BACKUP_PATH -type f -mtime +$AUTODELETEAFTER -exec rm {} \;
[ -d $ENCRYPTED_BACKUP_PATH ] && find $ENCRYPTED_BACKUP_PATH -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

if [ -z "$PASSPHRASE" ] ; then
    echo; echo 'DB backup is done without encryption:  '${DB_LATEST_FILE_NAME}' -> '${DB_OUTPUT_FILE_NAME}; echo
else
    echo; echo 'DB backup is done encrypted:  '${DB_LATEST_FILE_NAME}' -> '${ENCRYPTED_DB_OUTPUT_FILE_NAME}; echo
fi

echo "Script ended on... $(date +%c)"

