#!/bin/bash

# version - 1.0

# based on db-backup.sh script version 3.2.1

# changelog
# version: 1.0
#   - date: 2022-10-03
#   - first version

### Variables - Please do not add trailing slash in the PATHs

# To enable offsite backups...
# apt install awscli (or yum install awscli)
# legacy method
# run 'pip install awscli' (as root)
# aws configure (as normal user)

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/db-backups
ENCRYPTED_BACKUP_PATH=${HOME}/backups/encrypted-db-backups

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

# if WP is in a sub-directory, please leave this empty!
PUBLIC_DIR=public

# a passphrase for encryption, in order to being able to use almost any special characters use ""
PASSPHRASE=

# auto delete older backups after certain number days - default 60. YMMV
AUTODELETEAFTER=60

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
if [ -n "$PASSPHRASE" ] && [ ! -d "$ENCRYPTED_BACKUP_PATH" ] && [ "$(mkdir -p $ENCRYPTED_BACKUP_PATH)" ]; then
    echo "ENCRYPTED_BACKUP_PATH Is not found at $ENCRYPTED_BACKUP_PATH. the script can't create it, either!"
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
        if [ "$WP_DOMAIN" != "" ]; then
            DOMAIN=$WP_DOMAIN
        else
            echo 'Usage ${script_name} example.com (S3 bucket name)'; exit 1
        fi
    else
        DOMAIN=$1
    fi
fi

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
DOMAIN_FULL_PATH=$(echo $DOMAIN | awk '{gsub(/\//,"_")}; 1')

source ~/sites/${DOMAIN_FULL_PATH}/.env

WP_PATH=${SITES_PATH}/$DOMAIN/${PUBLIC_DIR}
if [ ! -d "$WP_PATH" ]; then
    echo; echo 'WordPress is not found at '$WP_PATH; echo "Usage ${script_name} domainname.tld (S3 bucket name)"; echo;
    exit 1
fi

if [ "$AWS_BUCKET" == ""  ]; then
    if [ "$2" != "" ]; then
        AWS_BUCKET=$2
    elif [ "$AWS_S3_BUCKET_NAME" != "" ]; then
        AWS_BUCKET=$AWS_S3_BUCKET_NAME
    fi
fi

DB_OUTPUT_FILE_NAME=${BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
ENCRYPTED_DB_OUTPUT_FILE_NAME=${ENCRYPTED_BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
DB_LATEST_FILE_NAME=${BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-latest.sql.gz

# take actual DB backup

mysqldump --add-drop-table -u$DB_USERNAME $DB_DATABASE -p"$DB_PASSWORD" | gzip > $DB_OUTPUT_FILE_NAME

[ -f $DB_LATEST_FILE_NAME ] && rm $DB_LATEST_FILE_NAME
if [ -n "$PASSPHRASE" ] ; then
    gpg --symmetric --passphrase $PASSPHRASE --batch -o ${ENCRYPTED_DB_OUTPUT_FILE_NAME} $DB_OUTPUT_FILE_NAME
    rm $DB_OUTPUT_FILE_NAME
    ln -s $ENCRYPTED_DB_OUTPUT_FILE_NAME $DB_LATEST_FILE_NAME
else
    ln -s $DB_OUTPUT_FILE_NAME $DB_LATEST_FILE_NAME
fi
if [ "$?" != "0" ]; then
    echo; echo 'Something went wrong while taking local backup!'
    rm -f $DB_OUTPUT_FILE_NAME &> /dev/null
fi

# external backup
if [ "$AWS_BUCKET" != "" ]; then
    if [ ! -e "$aws_cli" ] ; then
        echo; echo 'Did you run "pip install aws && aws configure"'; echo;
    fi

    if [ -z "$PASSPHRASE" ] ; then
        $aws_cli s3 cp $DB_OUTPUT_FILE_NAME s3://$AWS_BUCKET/${DOMAIN_FULL_PATH}/db-backups/ --only-show-errors
    else
        $aws_cli s3 cp $ENCRYPTED_DB_OUTPUT_FILE_NAME s3://$AWS_BUCKET/${DOMAIN_FULL_PATH}/encrypted-db-backups/ --only-show-errors
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
