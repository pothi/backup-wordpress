#!/bin/bash

### Variables - Please do not add trailing slash in the PATHs

# The name of the site
DEFAULT_SITE="domainname.com"

# path to wp-config.php file
# WP_CONFIG_PATH=${HOME}/public_html/wp-config.php

# where to store the backups?
BACKUP_PATH=${HOME}/Backup/databases

#-------- Do NOT Edit Below This Line --------#

# create the dir to keep backups, if not exists
# mkdir -p $BACKUP_PATH &> /dev/null
if [ ! -d "$BACKUP_PATH" ] && [ "$(mkdir -p $BACKUP_PATH)" ]; then
	echo 'BACKUP_PATH is not found at the expected path'
	echo 'You may want to create it manually'
	exit 1
fi


if [ "$1" == "" ]; then
    SITE_NAME=$DEFAULT_SITE
else
    SITE_NAME=$1
fi
SITE_PATH=${HOME}/sites/$SITE_NAME
if [ ! -d "$SITE_PATH" ]; then
	echo 'Site is not found at '$SITE_PATH
	exit 1
fi


# Delete backups that are two months older
MONTHSAGO=$(expr $(date +%m) - 2)
case $MONTHSAGO in
-1)
	rm -f ${BACKUP_PATH}/db-${SITE_NAME}-$(expr $(date +%Y) -1)-11-*.sql.gz &> /dev/null
	;;
0)
	rm -f ${BACKUP_PATH}/db-${SITE_NAME}-$(expr $(date +%Y) -1)-12-*.sql.gz &> /dev/null
	;;
*)
	rm -f ${BACKUP_PATH}/db-${SITE_NAME}-$(date +%Y)-0$MONTHSAGO-*.sql.gz &> /dev/null
	;;
10)
	rm -f ${BACKUP_PATH}/db-${SITE_NAME}-$(date +%Y)-10-*.sql.gz &> /dev/null
	;;
esac

# if exists, move the existing backup from $SITE_PATH to $BACKUP_PATH
# then store the new backup to $SITE_PATH
# to be taken as a backup by files-backup.sh script
mv $SITE_PATH/db-*.sql.gz ${BACKUP_PATH}/ &> /dev/null

if [ -f "${HOME}/sites/$SITE_NAME/wp-config.php" ]; then
    WP_CONFIG_PATH=${SITE_PATH}/wp-config.php
else
    WP_CONFIG_PATH=${SITE_PATH}/wordpress/wp-config.php
fi

if [ ! -f "$WP_CONFIG_PATH" ]; then
	echo 'wp-config.php file is not found at the expected path'
	exit 1
fi

# extract the password, username and name of the database from wp-config.php file
WPPASS=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_PASSWORD | awk '{print $3}')
WPUSER=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_USER | awk '{print $3}')
WPDB=`sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_NAME | awk '{print $3}'`

# create a backup using the information obtained through the above process
# mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB | gzip > ${BACKUP_PATH}/db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql.gz
mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB | gzip > ${SITE_PATH}/db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql.gz

# if gzip is not available
# mysqldump --add-drop-table -u$WPUSER -p$WPPASS $WPDB > ${BACKUP_PATH}db-${SITE_NAME}-$(date +%F_%H-%M-%S).sql

