#!/bin/bash

# version: 3.1.2

# Changelog
# version: 3.1.2
#   - date: 2022-11-29
#   - rewrite logic while attempting to create required directories
# v3.1.1
#   - date: 2020-11-24
#   - improve documentation
# v2
#   - date 2017-09-13
#   - change of script name
#   - change the output file name
#   - remove older backups using a simple find command; props - @wpbullet
# v1.1.2
#   - date 2017-09-04
#   - dynamically find the location of aws cli
# v1.1.1
#   - date 2017-09-03
#   - change the default dir name from Backup to backups
#   - no more syncing by default
# v1.1
#   - date 2017-05-05
#   - moved to nightly backups
#   - started excluding wp core files and uploads
#   - uploads files are now synced, rather than taken as part of regular nightly backup
# v1.0.4
#   - date 2017-03-06
#   - support for hard-coded variable AWS S3 Bucket Name
#   - support for environment files (.envrc / .env)
#   - skipped version 1.0.3
# v1.0.2
#   - date 2017-03-06
#   - support for hard-coded variable $DOMAIN

# Variable
AUTODELETEAFTER=30

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

# if WP is in a sub-directory, please leave this empty!
PUBLIC_DIR=public

### Variables
# You may hard-code the domain name and AWS S3 Bucket Name here
DOMAIN=
BUCKET_NAME=

#-------- Do NOT Edit Below This Line --------#

# attempt to create log directory if it doesn't exist
[ -d "${HOME}/log" ] || mkdir -p ${HOME}/log
if [ "$?" -ne 0 ]; then
    echo 'Log directory not found at ~/log'
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# attempt to create the backups directory, if it doesn't exist
[ -d "$BACKUP_PATH" ] || mkdir -p $BACKUP_PATH
if [ "$?" -ne 0 ]; then
    echo "BACKUP_PATH is not found at $BACKUP_PATH. The script can't create it, either!"
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# if passphrase is supplied, attempt to create backups directory for encrypt backups, if it doesn't exist
if [ -n "$PASSPHRASE" ]; then
    [ -d "$ENCRYPTED_BACKUP_PATH" ] || mkdir -p $ENCRYPTED_BACKUP_PATH
    if [ "$?" -ne 0 ]; then
        echo "ENCRYPTED_BACKUP_PATH Is not found at $ENCRYPTED_BACKUP_PATH. the script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

log_file=${HOME}/log/backups.log
exec > >(tee -a ${log_file} )
exec 2> >(tee -a ${log_file} >&2)

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin

declare -r script_name=$(basename "$0")
declare -r timestamp=$(date +%F_%H-%M-%S)
declare -r aws_cli=`which aws`
declare -r wp_cli=`which wp`

if [ -z "$wp_cli" ]; then
    echo "wp-cli is not found in $PATH. Exiting."
    exit 1
fi

if [ -z "$aws_cli" ]; then
    echo "aws-cli is not found in $PATH. Exiting."
    exit 1
fi

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
            echo "Usage ${script_name} domainname.com (S3 bucket name)"; exit 1
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

# path to be backed up
WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
[ ! -d "$WP_PATH" ] && echo "WordPress is not found at $WP_PATH" &&  exit 1

echo "Script started on... $(date +%c)"

# path to be excluded from the backup
# no trailing slash, please
EXCLUDE_BASE_PATH=${DOMAIN}
if [ "$PUBLIC_DIR" != "" ]; then
    EXCLUDE_BASE_PATH=${EXCLUDE_BASE_PATH}/${PUBLIC_DIR}
fi  

declare -A EXC_PATH
EXC_PATH[1]=${EXCLUDE_BASE_PATH}/wp-content/cache
EXC_PATH[2]=${EXCLUDE_BASE_PATH}/wp-content/debug.log
EXC_PATH[3]=${EXCLUDE_BASE_PATH}/.git
EXC_PATH[4]=${EXCLUDE_BASE_PATH}/wp-content/uploads
# need more? - just use the above format

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
    CURRENT_EXC_PATH=${EXC_PATH[$i]}
    EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
    # remember the trailing space; we'll use it later
done

BACKUP_FILE_NAME=${BACKUP_PATH}/files-without-uploads-${DOMAIN}-$timestamp.tar.gz

# let's do it using tar
# Create a fresh backup
tar hczf ${BACKUP_FILE_NAME} -C ${SITES_PATH} ${EXCLUDES} ${DOMAIN} &> /dev/null

if [ "$BUCKET_NAME" != "" ]; then
    if [ ! -e "$aws_cli" ] ; then
        echo; echo 'Did you run "pip install aws && aws configure"'; echo;
    fi

    $aws_cli s3 cp ${BACKUP_FILE_NAME} s3://$BUCKET_NAME/${DOMAIN}/files-backup-without-uploads/ --only-show-errors
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking offsite backup'; echo
        echo "Check $LOG_FILE for any log info"; echo
    else
        echo; echo 'Offsite backup successful'; echo
    fi
fi

# Auto delete backups 
find $BACKUP_PATH -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo; echo 'Files backup (without uploads) is done; please check the latest backup in '${BACKUP_PATH}'.';
echo "Full path to the latest backup is ${BACKUP_FILE_NAME}"

echo "Script ended on... $(date +%c)"
echo
