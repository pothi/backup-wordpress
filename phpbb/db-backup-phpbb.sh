#!/usr/bin/env bash

# version - 1

### Variables - Please do not add trailing slash in the PATHs

# To enable offsite backups...
# apt install awscli (or yum install awscli)
# legacy method
# run 'pip install awscli' (as root)
# aws configure (as normal user)

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/db-backups
encrypted_backup_path=${HOME}/backups/encrypted-db-backups

# the script assumes that the sites are stored like...
# ~/sites/example.com/public
# ~/sites/example.net/public
# ~/sites/example.org/public and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

PUBLIC_DIR=public

# a passphrase for encryption, in order to being able to use almost any special characters use ""
PASSPHRASE=

# auto delete older backups after certain number days - default 60. YMMV
AUTODELETEAFTER=120

# You may hard-code the domain name
DOMAIN=

# AWS Variable can be hard-coded here
AWS_S3_BUCKET_NAME=

# ref: http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=
AWS_PROFILE=

#-------- Do NOT Edit Below This Line --------#

script_name=$(basename "$0")

# create log directory if it doesn't exist
[ ! -d ${HOME}/log ] && mkdir ${HOME}/log

LOG_FILE=${HOME}/log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

echo "Script started on... $(date +%c)"

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin

which aws &> /dev/null && declare -r aws_cli=`which aws`
declare -r timestamp=$(date +%F_%H-%M-%S)

let AUTODELETEAFTER--

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo 'Log directory not found'
    echo "Please create it manually at $HOME/log and then re-run this script"
    exit 1
fi 

# create the dir to keep backups, if not exists
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
    echo "BACKUP_PATH is not found at $BACKUP_PATH. The script can't create it, either!"
    echo 'You may want to create it manually'
    exit 1
fi
if [ -n "$PASSPHRASE" ] && [ ! -d "$encrypted_backup_path" ] && [ "$(mkdir -p $encrypted_backup_path)" ]; then
    echo "encrypted_backup_path is not found at $encrypted_backup_path. the script can't create it, either!"
    echo 'you may want to create it manually'
    exit 1
fi

# get environment variables
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
        echo 'Usage ${script_name} example.com (S3 bucket name)'; exit 1
    else
        DOMAIN=$1
    fi
fi

phpbb_path=${SITES_PATH}/$DOMAIN/${PUBLIC_DIR}
if [ ! -d "$phpbb_path" ]; then
    echo; echo 'WordPress is not found at '$phpbb_path; echo "Usage ${script_name} domainname.tld (S3 bucket name)"; echo;
    exit 1
fi

if [ "$AWS_BUCKET" == ""  ]; then
    if [ "$2" != "" ]; then
        AWS_BUCKET=$2
    elif [ "$AWS_S3_BUCKET_NAME" != "" ]; then
        AWS_BUCKET=$AWS_S3_BUCKET_NAME
    fi
fi

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
DOMAIN_FULL_PATH=$(echo $DOMAIN | awk '{gsub(/\//,"_")}; 1')

DB_OUTPUT_FILE_NAME=${BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
ENCRYPTED_DB_OUTPUT_FILE_NAME=${encrypted_backup_path}/db-${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
DB_LATEST_FILE_NAME=${BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-latest.sql.gz

# when installed by the OS provided phpBB package.
CONFIG_FILE_PATH=${phpbb_path}/database.inc.php
# in some installations, it is with config.php file
# CONFIG_FILE_PATH=${phpbb_path}/config.php

DB_NAME=$(/bin/sed -n "/dbname/ s/[';\r]//gp" ${CONFIG_FILE_PATH} | /usr/bin/awk -F '=' '{print $2}')
DB_USER=$(/bin/sed -n "/dbuser/ s/[';\r]//gp" ${CONFIG_FILE_PATH} | /usr/bin/awk -F '=' '{print $2}')
DB_PASS=$(/bin/sed -n "/dbpass/ s/[';\r]//gp" ${CONFIG_FILE_PATH} | /usr/bin/awk -F '=' '{print $2}')

# take actual DB backup
    /usr/bin/mysqldump --add-drop-table ${DB_NAME} -u${DB_USER} -p${DB_PASS} | /bin/gzip > $DB_OUTPUT_FILE_NAME
    rm $DB_LATEST_FILE_NAME
    ln -s $DB_OUTPUT_FILE_NAME $DB_LATEST_FILE_NAME
    if [ ! -z "$PASSPHRASE" ] ; then
        gpg --symmetric --passphrase $PASSPHRASE --batch -o ${ENCRYPTED_DB_OUTPUT_FILE_NAME} $DB_OUTPUT_FILE_NAME
        rm $DB_OUTPUT_FILE_NAME
    fi
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking local backup!'
        echo "Check $LOG_FILE for any further log info. Exiting now!"; echo; exit 2
    fi

# external backup
if [ "$AWS_BUCKET" != "" ]; then
    if [ ! -e "$aws_cli" ] ; then
        echo; echo 'Did you run "pip install aws && aws configure"'; echo;
    fi

    if [ -z "$PASSPHRASE" ] ; then
        $aws_cli s3 cp $DB_OUTPUT_FILE_NAME s3://$AWS_BUCKET/${DOMAIN_FULL_PATH}/databases/
    else
        $aws_cli s3 cp $ENCRYPTED_DB_OUTPUT_FILE_NAME s3://$AWS_BUCKET/${DOMAIN_FULL_PATH}/databases/
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
[ -d $encrypted_backup_path ] && find $encrypted_backup_path -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo "Script ended on... $(date +%c)"

if [ -z "$PASSPHRASE" ] ; then
    echo; echo 'DB backup is done; please check the latest backup at '${BACKUP_PATH}'.'; echo
else
    echo; echo 'DB backup is done; please check the latest backup at '${ENCRYPTED_BACKUP_PATH}'.'; echo
fi

