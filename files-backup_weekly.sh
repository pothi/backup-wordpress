#!/bin/bash

### Variables
# path to be backed up
INC_PATH=/home/username/public_html/

# path to be excluded from the backup
EXC_PATH_1=/home/username/public_html/wp-content/cache
EXC_PATH_2=/home/username/public_html/cgi-bin

# The name of the site
SITE_NAME=tinywp.com

# where to store the backup file/s
BACKUP_PATH=/home/username/backups/files/

### Do not edit below this line ###

BACKUP_FILE_NAME=${BACKUP_PATH}files-${SITE_NAME}-$(date +%F_%H-%M-%S).tar.gz

# let's do it using tar
tar czf $BACKUP_FILE_NAME --exclude=$EXC_PATH_1 --exclude=$EXC_PATH_2 $INC_PATH &> /dev/null
