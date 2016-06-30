#!/bin/bash

# Author: Pothi Kalimuthu (@pothi)
# if you remove this script, please remove the corresponding line in crontab too
# please change WP_CONFIG_PATH accordingly without trailing slash

WP_CONFIG_PATH="/var/www/yourdreamsite.com"

LOG_FILE=${HOME}/log/clean-wp-db.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

#-------- Do NOT Edit Below This Line --------#

# check if log directory exists
if [ ! -d "${HOME}/log" ] && [ "$(mkdir -p ${HOME}/log)" ]; then
    echo 'Log directory not found'
    exit 1
fi 

echo; echo "Collecting info about DB"; echo

if [ ! -f "${WP_CONFIG_PATH}/wp-config.php" ]; then
	echo 'wp-config.php not found. please check your WP_CONFIG_PATH in the script.'
	exit 1
fi

WPDB=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_NAME | $(which awk) '{print $3}'`
WPPREFIX=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) '^\$table_prefix' | $(which awk) '{print $3}'`
WPUSER=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_USER | $(which awk) '{print $3}'`
WPPASS=`$(which sed) "s/[()',;]/ /g" ${WP_CONFIG_PATH}/wp-config.php | $(which grep) DB_PASSWORD | $(which awk) '{print $3}'`

# echo 'DB: '$WPDB
# echo 'Prefix: '$WPPREFIX
# echo 'User: '$WPUSER
# echo 'Pass: '$WPPASS
# echo 'DB: '$WPDB
# echo 'Prefix: '$WPPREFIX
# echo 'User: '$WPUSER
# echo 'Pass: '$WPPASS

mkdir ~/log/ &> /dev/null

echo 'Date: '$(date +%F)
echo 'Time: '$(date +%H-%M-%S)

echo 'Cleaning up akismet junk in commentsmeta table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'commentmeta WHERE meta_key LIKE "%akismet%";'

echo 'Cleaning up unconnected comments in commentsmeta table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'commentmeta WHERE comment_id NOT IN ( SELECT comment_id FROM '$WPPREFIX'comments );'

echo 'Cleaning up spam comments'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'comments WHERE '$WPPREFIX'comments.comment_approved = "spam";'

echo 'Cleaning up postmeta table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE pm FROM '$WPPREFIX'postmeta pm LEFT JOIN '$WPPREFIX'posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;'

echo 'Cleaning up postmeta table'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE pm FROM '$WPPREFIX'postmeta pm LEFT JOIN '$WPPREFIX'posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;'

echo 'Cleaning up old revisions (of above 31 days)'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'posts` WHERE `post_type` = "revision" AND `post_date` < DATE_SUB( CURDATE(), INTERVAL 31 DAY);'

echo 'Optimizing tables'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'options;'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'commentmeta;'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'comments;'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'postmeta;'
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'posts;'
$(which mysqlcheck) -o -vvv -u$WPUSER -p$WPPASS $WPDB

echo; echo "In case of an error, please look at the log file at $LOG_FILE"; echo
