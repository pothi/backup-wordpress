#!/bin/bash

# Takes backup of all the sites
# Keeps 4 latest backups
# Removes oldest backups (older than 4 backups)

### Files are named in the following way...
# all-files-xyz-1-date.tar.gz (latest backup)
# all-files-xyz-2-date.tar.gz (older backup)
# all-files-xyz-3-date.tar.gz (older backup)
# all-files-xyz-4-date.tar.gz (oldest backup)

### Variables

# where to store the backup file/s
BACKUP_PATH=${HOME}/Backup/files/
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo 'BACKUP_PATH is not found at '$BACKUP_PATH
	echo 'You may want to create it manually'
	exit 1
fi


# path to be backed up
SITE_PATH=${HOME}/sites/domainname.com
if [ ! -d "$SITE_PATH" ]; then
	echo 'Site is not found at '$SITE_PATH
	exit 1
fi


# path to be excluded from the backup
# no trailing slash, please
EXC_PATH_1=$SITE_PATH/wordpress/wp-content/cache
EXC_PATH_2=$SITE_PATH/wordpress/wp-content/backups
EXC_PATH_3=$SITE_PATH/wordpress/wp-content/uploads/backups

### Do not edit below this line ###

# For all sites
BACKUP_FILE_NAME=${BACKUP_PATH}all-files-$(hostname -f | awk -F $(hostname). '{print $2}')

# Remove the oldeest file
rm ${BACKUP_FILE_NAME}-4-* &> /dev/null

# Rename other files to make them older
rename -- -3- -4- ${BACKUP_FILE_NAME}-3-* &> /dev/null
rename -- -2- -3- ${BACKUP_FILE_NAME}-2-* &> /dev/null
rename -- -1- -2- ${BACKUP_FILE_NAME}-1-* &> /dev/null

# let's do it using tar
# Create a fresh backup
tar hczf ${BACKUP_FILE_NAME}-1-$(date +%F_%H-%M-%S).tar.gz --exclude=$EXC_PATH_1 --exclude=$EXC_PATH_2 --exclude=$EXC_PATH_3 $SITE_PATH &> /dev/null
