#!/bin/bash

# Author: Pothi Kalimuthu (@pothi)
# if you remove this script, please remove the corresponding line in crontab too
# please change WP_CONFIG_PATH accordingly without trailing slash

SCRIPT_NAME=clean-wp-transients.sh

LOG_FILE=${HOME}/log/clean-wp-transients.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

#-------- Do NOT Edit Below This Line --------#

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo 'Log directory not found. Please create it manually and then re-run this script.'
    exit 1
fi 

DEFAULT_SITE="domainname.com"

if [ "$1" == "" ]; then
    DOMAIN=$DEFAULT_SITE
else
    DOMAIN=$1
fi
SITE_PATH=${HOME}/sites/$DOMAIN
if [ ! -d "$SITE_PATH" ]; then
	echo 'Site is not found at '$SITE_PATH; echo "Usage ${SCRIPT_NAME} domainname.tld (S3 bucket name)";
	exit 1
fi

if [ -f "${HOME}/sites/$DOMAIN/wp-config.php" ]; then
    WP_CONFIG_PATH=${SITE_PATH}/wp-config.php
else
    WP_CONFIG_PATH=${SITE_PATH}/wordpress/wp-config.php
fi
# if local-config.php presents, it takes precedence
if [ -f "${HOME}/sites/$DOMAIN/local-config.php" ]; then
    WP_CONFIG_PATH=${SITE_PATH}/local-config.php
else
    WP_CONFIG_PATH=${SITE_PATH}/wordpress/local-config.php
fi
# set the path to wp-config.php manually
# WP_CONFIG_PATH="/var/www/yourdreamsite.com"

echo; echo "Collecting info about the DB"; echo

if [ ! -f "${WP_CONFIG_PATH}" ]; then
	echo 'wp-config.php not found. please check your WP_CONFIG_PATH in the script.'
	exit 1
fi

# WPDB=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH} | $(which grep) DB_NAME | $(which awk) '{print $3}'`
# WPUSER=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH} | $(which grep) DB_USER | $(which awk) '{print $3}'`
# WPPASS=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH} | $(which grep) DB_PASSWORD | $(which awk) '{print $3}'`
WPPREFIX=`sed "s/[()',;]/ /g" ${WP_CONFIG_PATH} | grep table_prefix | awk '{print $3}'`

WPPASS=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_PASSWORD | awk '{print $3}')
WPUSER=$(sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_USER | awk '{print $3}')
WPDB=`sed "s/[()',;]/ /g" $WP_CONFIG_PATH | grep DB_NAME | awk '{print $3}'`

# echo 'DB: '$WPDB
# echo 'Prefix: '$WPPREFIX
# echo 'User: '$WPUSER
# echo 'Pass: '$WPPASS
# echo 'DB: '$WPDB >> ~/log/clean-wp-transients.log
# echo 'Prefix: '$WPPREFIX >> ~/log/clean-wp-transients.log
# echo 'User: '$WPUSER >> ~/log/clean-wp-transients.log
# echo 'Pass: '$WPPASS >> ~/log/clean-wp-transients.log

echo 'Cleaning up transients in options table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'options` WHERE `option_name` LIKE ("_transient_%");'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'options` WHERE `option_name` LIKE ("_site_transient_%");'

echo 'Optimizing options table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'options;'

echo; echo "If you see an error message above, please look at the log file at $LOG_FILE"; echo
