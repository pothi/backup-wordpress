#!/bin/bash

# Author: Pothi Kalimuthu (@pothi)
# if you remove this script, please remove the corresponding line in crontab too
# please change WP_CONFIG_PATH accordingly without trailing slash

WP_CONFIG_PATH="/var/www/yourdreamsite.com"

echo; echo "Collecting info about the DB"; echo

if [ ! -f "${WP_CONFIG_PATH}/wp-config.php" ]; then
	echo 'wp-config.php not found. please check your WP_CONFIG_PATH in the script.'
	exit 1
fi

WPDB=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_NAME | $(which awk) '{print $3}'`
WPPREFIX=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) table_prefix | $(which awk) '{print $3}'`
WPUSER=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_USER | $(which awk) '{print $3}'`
WPPASS=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_PASSWORD | $(which awk) '{print $3}'`

# echo 'DB: '$WPDB
# echo 'Prefix: '$WPPREFIX
# echo 'User: '$WPUSER
# echo 'Pass: '$WPPASS
# echo 'DB: '$WPDB >> ~/log/clean-wp-transients.log
# echo 'Prefix: '$WPPREFIX >> ~/log/clean-wp-transients.log
# echo 'User: '$WPUSER >> ~/log/clean-wp-transients.log
# echo 'Pass: '$WPPASS >> ~/log/clean-wp-transients.log

mkdir ~/log/ &> /dev/null

echo 'Cleaning up transients in options table'
echo 'Cleaning up transients in options table' >> ~/log/clean-wp-transients.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'options` WHERE `option_name` LIKE ('_transient_%');' &>> ~/log/clean-wp-transients.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'options` WHERE `option_name` LIKE ("_site_transient_%");' &>> ~/log/clean-wp-transients.log

echo 'Optimizing options table'
echo 'Optimizing options table' >> ~/log/clean-wp-transients.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'options;' >> ~/log/clean-wp-transients.log

echo; echo 'If you see an error message above, please look at the log file at ~/log/clean-wp-transients.log'; echo

