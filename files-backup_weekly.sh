#!/bin/bash

# Takes backup of all the sites

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
BACKUP_FILE_NAME=${BACKUP_PATH}all-files-$(hostname -f | awk -F $(hostname). '{print $2}')-$(date +%F_%H-%M-%S).tar.gz

# let's do it using tar
tar czf $BACKUP_FILE_NAME --exclude=$EXC_PATH_1 --exclude=$EXC_PATH_2 --exclude=$EXC_PATH_3 $INC_PATH &> /dev/null
