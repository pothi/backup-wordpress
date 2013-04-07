#!/bin/bash

### Variables
# The name of the user
USERNAME=pothi

# The name of the site
SITE_NAME=tinywp.com

# where to store the backup file/s
BACKUP_PATH=/home/${USERNAME}/backups/files/

# path to be backed up
INC_PATH=/home/${USERNAME}/public_html/

# path to be excluded from the backup
# no trailing slash, please
EXC_PATH_1=/home/${USERNAME}/public_html/wp-content/cache
EXC_PATH_2=/home/${USERNAME}/public_html/cgi-bin

### Do not edit below this line ###

BACKUP_FILE_NAME=${BACKUP_PATH}files-${SITE_NAME}-$(date +%F_%H-%M-%S).tar.gz

# let's do it using tar
tar czf $BACKUP_FILE_NAME --exclude=$EXC_PATH_1 --exclude=$EXC_PATH_2 $INC_PATH &> /dev/null
