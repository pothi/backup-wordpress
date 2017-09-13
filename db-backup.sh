#!/bin/bash

# version - 1.2
# for changelog, please see the file named changelog-db-backup.txt

### Variables - Please do not add trailing slash in the PATHs

# To enable offsite backups...
# apt install awscli (or yum install awscli)
# legacy method
# run 'pip install awscli' (as root)
# aws configure (as normal user)

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/databases

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

# if WP is in a sub-directory, please leave this empty!
PUBLIC_DIR=public

# auto delete older backups after certain number days - default 60. YMMV
AUTODELETEAFTER=60

# You may hard-code the domain name
DOMAIN=

# AWS Variable can be hard-coded here
AWS_BUCKET=

# ref: http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=
AWS_PROFILE=

#-------- Do NOT Edit Below This Line --------#

SCRIPT_NAME=db-backup.sh

LOG_FILE=${HOME}/log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

# declare -r wp_cli=/usr/local/bin/wp
declare -r wp_cli=$(which wp)
declare -r aws_cli=$(which aws)
declare -r timestamp=$(date +%F_%H-%M-%S)

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo 'Log directory not found'
    echo "Please create it manually at $HOME/log and then re-run this script"
    exit 1
fi 

# create the dir to keep backups, if not exists
# mkdir -p $BACKUP_PATH &> /dev/null
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo "BACKUP_PATH is not found at $BACKUP_PATH . The script can't create it, either!"
	echo 'You may create it manually and then re-run this script'
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
            echo 'Usage ${SCRIPT_NAME} example.com (S3 bucket name)'; exit 1
        fi
    else
        DOMAIN=$1
    fi
fi

WP_PATH=${SITES_PATH}/$DOMAIN/${PUBLIC_DIR}
if [ ! -d "$WP_PATH" ]; then
	echo; echo 'WordPress is not found at '$WP_PATH; echo "Usage ${SCRIPT_NAME} domainname.tld (S3 bucket name)"; echo;
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

# take actual DB backup
if [ -f "$wp_cli" ]; then
    $wp_cli --path=${WP_PATH} db export --add-drop-table - | gzip > $DB_OUTPUT_FILE_NAME
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking local backup!'
		echo "Check $LOG_FILE for any further log info. Exiting now!"; echo; exit 2
    fi
else
    echo 'Please install wp-cli and re-run this script'; exit 1;
fi

# external backup
if [ "$AWS_BUCKET" != "" ]; then
	if [ ! -e "$aws_cli" ] ; then
		echo; echo 'Did you run "pip install aws && aws configure"'; echo;
	fi

    $aws_cli s3 cp ${BACKUP_PATH}/db-${DOMAIN_FULL_PATH}-${timestamp}.sql.gz s3://$AWS_BUCKET/${DOMAIN_FULL_PATH}/databases/
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking offsite backup';
		echo "Check $LOG_FILE for any log info"; echo
    else
        echo; echo 'Offsite backup successful'; echo
    fi
fi

# Auto delete backups 
find $BACKUP_PATH -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo; echo 'DB backup done; please check the latest backup at '${BACKUP_PATH}'.'; echo
