#!/bin/bash

# Variable
TOTAL_BACKUPS=4

# if you'd like to enable offsite backup...
# run 'pip install aws'
# aws configure

LOG_FILE=${HOME}log/backups.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

# Takes backup of all the sites
# Assume we need 4 latest backups
# This script removes oldest backups (older than 4 backups)

### Files are named in the following way...
# all-files-xyz-1-date.tar.gz (latest backup)
# all-files-xyz-2-date.tar.gz (older backup)
# all-files-xyz-3-date.tar.gz (older backup)
# all-files-xyz-4-date.tar.gz (oldest backup)

### Variables

DOMAIN=

if [ "$1" == "" ]; then
    if [ -f "$HOME.my.exports" ]; then
        source ~/.my.exports
        DOMAIN=$MY_DOMAIN
    else
		echo 'Usage files-backup.sh domainname.com (S3 bucket name)'; exit 1
    fi
else
    DOMAIN=$1
fi

# path to be backed up
SITE_PATH=${HOME}sites/${DOMAIN}
if [ ! -d "$SITE_PATH" ]; then
	echo 'Site is not found at '$SITE_PATH
	exit 1
fi


# where to store the backup file/s
BACKUP_PATH=${HOME}Backup/files
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo 'BACKUP_PATH is not found at '$BACKUP_PATH
	echo 'You may want to create it manually'
	exit 1
fi


# path to be excluded from the backup
# no trailing slash, please
declare -A EXC_PATH
EXC_PATH[1]=${DOMAIN}/wordpress/wp-content/cache
EXC_PATH[2]=${DOMAIN}/wordpress/wp-content/object-cache.php
EXC_PATH[3]=${DOMAIN}/wordpress/wp-content/debug.log
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
BACKUP_FILE_NAME=${BACKUP_PATH}/files-${DOMAIN}

# Remove the oldest file
rm ${BACKUP_FILE_NAME}-$TOTAL_BACKUPS-* &> /dev/null

# Rename other files to make them older
for i in `seq $TOTAL_BACKUPS -1 1`
do
	# let's first try to do CentOS way of doing things
    rename -- -$(($i-1))- -$i- ${BACKUP_FILE_NAME}-$(($i-1))-* &> /dev/null
    if [ "$?" != 0 ]; then
		# not do it in Debian way
        rename 's/-'$(($i-1))'-/-'$i'-/' ${BACKUP_FILE_NAME}-$(($i-1))-* &> /dev/null
    fi
done

# let's do it using tar
# Create a fresh backup
CURRENT_DATE_TIME=$(date +%F_%H-%M-%S)
tar hczf ${BACKUP_FILE_NAME}-1-$CURRENT_DATE_TIME.tar.gz -C ${HOME}sites ${EXCLUDES} ${DOMAIN} &> /dev/null

if [ "$2" != "" ]; then
	if [ ! -e "/usr/local/bin/aws" ] ; then
		echo; echo 'Did you run "pip install aws && aws configure"'; echo;
	fi

    /usr/local/bin/aws s3 cp ${BACKUP_FILE_NAME}-1-$CURRENT_DATE_TIME.tar.gz s3://$2/backups/files/
    if [ "$?" != "0" ]; then
        echo; echo 'Something went wrong while taking offsite backup'; echo
		echo "Check $LOG_FILE for any log info"; echo
    else
        echo; echo 'Offsite backup successful'; echo
    fi
fi

echo; echo 'Files backup done; please check the latest backup at '${BACKUP_PATH}'.'; echo
