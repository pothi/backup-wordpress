#!/bin/bash

# version: 2

# Changelog
# v2
#   - date 2017-09-13
#   - change of script name
#   - change the output file name
#	- remove older backups using a simple find command; props - @wpbullet
#   - derived from files-backup-without-uploads.sh scripts

# this script is basically
# files-backup-without-uploads.sh script + part of db-backup.sh script
# from files-backup-without-uploads.sh script, we do not exclude uploads directory - just removed the line from it

### Variables ###

# auto delete older backups after certain number days - default 30. YMMV
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

LOG_FILE=${HOME}/log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

#------------- from db-script.sh --------------#
declare -r wp_cli=$(which wp)
#------------- end of snippet from db-script.sh --------------#

declare -r aws_cli=$(which aws)
declare -r timestamp=$(date +%F_%H-%M-%S)

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
WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
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
EXC_PATH[1]=${DOMAIN}/${PUBLIC_DIR}/wp-content/cache
EXC_PATH[2]=${DOMAIN}/${PUBLIC_DIR}/wp-content/debug.log
EXC_PATH[3]=${DOMAIN}/${PUBLIC_DIR}/.git
# need more? - just use the above format

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
	CURRENT_EXC_PATH=${EXC_PATH[$i]}
	EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
	# remember the trailing space; we'll use it later
done

#------------- from db-script.sh --------------#
DB_OUTPUT_FILE_NAME=${SITES_PATH}/${DOMAIN}/db-$timestamp.sql.gz

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
#------------- end of snippet from db-script.sh --------------#

FULL_BACKUP_FILE_NAME=${BACKUP_PATH}/full-backup-${DOMAIN}-$timestamp.tar.gz

# let's do it using tar
# Create a fresh backup
tar hczf ${FULL_BACKUP_FILE_NAME} -C ${SITES_PATH} ${EXCLUDES} ${DOMAIN} &> /dev/null

# remove the reduntant DB backup
rm $DB_OUTPUT_FILE_NAME

if [ "$BUCKET_NAME" != "" ]; then
	if [ ! -e "$aws_cli" ] ; then
		echo; echo 'Did you run "pip install aws && aws configure"'; echo;
	fi

    $aws_cli s3 cp ${FULL_BACKUP_FILE_NAME} s3://$BUCKET_NAME/${DOMAIN}/backups/files/
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
echo "Full path to the latest backup is ${FULL_BACKUP_FILE_NAME}"
echo
