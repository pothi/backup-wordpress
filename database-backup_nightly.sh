#!/bin/bash

### Variables
# The name of the site
DEFAULT_SITE="domainname.com"

# path to wp-config.php file
# WP_CONFIG_PATH=${HOME}/public_html/wp-config.php

# where to store the backups?
BACKUP_PATH=${HOME}/Backup/databases/

#-------- Do NOT Edit Below This Line --------#

if [$1 == ""]; then
    SITE_NAME=$DEFAULT_SITE
else
    SITE_NAME=$1
fi

WP_CONFIG_PATH=${HOME}/sites/$SITE_NAME/wp-config.php

# extract the password, username and name of the database from wp-config.php file
WPPASS=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_PASSWORD | awk '{print $3}')
WPUSER=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_USER | awk '{print $3}')
WPDB=`sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_NAME | awk '{print $3}'`

# create a backup using the information obtained through the above process
mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB | gzip > ${BACKUP_PATH}db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql.gz

# if gzip is not available
# mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB > ${BACKUP_PATH}db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql

