#!/bin/bash

# version: 2

# Changelog
# v2
#   - date 2017-09-13
#   - change of script name
#   - change the output file name
#	- remove older backups using a simple find command; props - @wpbullet
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
# not-applicable for this script
# PUBLIC_DIR=public

### Variables
# You may hard-code the domain name and AWS S3 Bucket Name here
DOMAIN=
BUCKET_NAME=

#-------- Do NOT Edit Below This Line --------#

LOG_FILE=${HOME}/log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

declare -r aws_cli=$(which aws)

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo "Log directory not found. The script can't create it, either!"
    echo "Please create it manually at $HOME/log and then re-run this script"
    exit 1
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
            echo 'Usage files-backup.sh domainname.com (S3 bucket name)'; exit 1
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
WP_PATH=${SITES_PATH}/${DOMAIN}
if [ ! -d "$WP_PATH" ]; then
	echo "$WP_PATH is not found. Please check the paths and adjust the variables in the script. Exiting now..."
	exit 1
fi


# where to store the backup file/s
BACKUP_PATH=${HOME}/backups/files
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo "BACKUP_PATH is not found at $BACKUP_PATH. The script can't create it, either!"
	echo 'You may want to create it manually'
	exit 1
fi

# path to be excluded from the backup
# no trailing slash, please
declare -A EXC_PATH
EXC_PATH[1]=${WP_PATH}/wp-content/cache
EXC_PATH[2]=${WP_PATH}/wp-content/debug.log
EXC_PATH[3]=${WP_PATH}/wp-content/uploads
# need more? - just use the above format

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
	CURRENT_EXC_PATH=${EXC_PATH[$i]}
	EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
	# remember the trailing space; we'll use it later
done

### Do not edit below this line ###

# For all sites
# BACKUP_FILE_NAME=${BACKUP_PATH}all-files-$(hostname -f | awk -F $(hostname). '{print $2}')
BACKUP_FILE_NAME=${BACKUP_PATH}/files-without-uploads-${DOMAIN}-$CURRENT_DATE_TIME.tar.gz

# let's do it using tar
# Create a fresh backup
CURRENT_DATE_TIME=$(date +%F_%H-%M-%S)
tar hczf ${BACKUP_FILE_NAME} -C ${SITES_PATH} ${EXCLUDES} ${DOMAIN} &> /dev/null

if [ "$BUCKET_NAME" != "" ]; then
	if [ ! -e "$aws_cli" ] ; then
		echo; echo 'Did you run "pip install aws && aws configure"'; echo;
	fi

    $aws_cli s3 cp ${BACKUP_FILE_NAME}-1-$CURRENT_DATE_TIME.tar.gz s3://$BUCKET_NAME/${DOMAIN}/backups/files/
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
echo
