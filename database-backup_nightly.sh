#!/bin/bash

### Variables
# path to wp-config.php file
WP_CONFIG_PATH=/home/username/public_html/wp-config.php

# where to store the backups?
BACKUP_PATH=/home/username/backups/databases/

# The name of the site
SITE_NAME=tinywp.com

#-------- Do NOT Edit Below This Line --------#

# extract the password, username and name of the database from wp-config.php file
WPPASS=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_PASSWORD | awk '{print $3}')
WPUSER=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_USER | awk '{print $3}')
WPDB=`sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_NAME | awk '{print $3}'`

# create a backup using the information obtained through the above process
mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB > ${BACKUP_PATH}db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql

