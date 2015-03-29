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

# path to be backed up
INC_PATH=${HOME}/sites/

# path to be excluded from the backup
# no trailing slash, please
EXC_PATH_1=$INC_PATH/wp-content/cache
EXC_PATH_2=$INC_PATH/wp-content/backups
EXC_PATH_3=$INC_PATH/wp-content/uploads/backups

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
tar czf ${BACKUP_FILE_NAME}-1-$(date +%F_%H-%M-%S).tar.gz --exclude=$EXC_PATH_1 --exclude=$EXC_PATH_2 --exclude=$EXC_PATH_3 $INC_PATH &> /dev/null

