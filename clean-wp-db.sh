#!/bin/bash

# Author: Pothi Kalimuthu (@pothi)
# if you remove this script, please remove the corresponding line in crontab too
# please change WP_CONFIG_PATH accordingly without trailing slash

WP_CONFIG_PATH="/var/www/yourdreamsite.com"

echo; echo "Collecting info about DB"; echo

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
# echo 'DB: '$WPDB >> ~/log/clean-wp-db.log
# echo 'Prefix: '$WPPREFIX >> ~/log/clean-wp-db.log
# echo 'User: '$WPUSER >> ~/log/clean-wp-db.log
# echo 'Pass: '$WPPASS >> ~/log/clean-wp-db.log

mkdir ~/log/ &> /dev/null

echo 'Cleaning up akismet junk in commentsmeta table'
echo 'Cleaning up akismet junk in commentsmeta table' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'commentmeta WHERE meta_key LIKE "%akismet%";' >> ~/log/clean-wp-db.log

echo 'Cleaning up unconnected comments in commentsmeta table'
echo 'Cleaning up unconnected comments in commentsmeta table' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'commentmeta WHERE comment_id NOT IN ( SELECT comment_id FROM '$WPPREFIX'comments );' >> ~/log/clean-wp-db.log

echo 'Cleaning up spam comments'
echo 'Cleaning up spam comments' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM '$WPPREFIX'comments WHERE '$WPPREFIX'comments.comment_approved = "spam";' >> ~/log/clean-wp-db.log

echo 'Cleaning up postmeta table'
echo 'Cleaning up postmeta table' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE pm FROM '$WPPREFIX'postmeta pm LEFT JOIN '$WPPREFIX'posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;' >> ~/log/clean-wp-db.log

echo 'Cleaning up postmeta table'
echo 'Cleaning up postmeta table' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE pm FROM '$WPPREFIX'postmeta pm LEFT JOIN '$WPPREFIX'posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;' >> ~/log/clean-wp-db.log

echo 'Cleaning up old revisions (of above 31 days)'
echo 'Cleaning up old revisions (of above 31 days)' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'DELETE FROM `'$WPPREFIX'posts` WHERE `post_type` = "revision" AND `post_date` < DATE_SUB( CURDATE(), INTERVAL 31 DAY);' >> ~/log/clean-wp-db.log

echo 'Optimizing tables'
echo 'Optimizing tables' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'options;' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'commentmeta;' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'comments;' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'postmeta;' >> ~/log/clean-wp-db.log
$(which mysql) -vvv -u$WPUSER -p$WPPASS $WPDB -e 'OPTIMIZE TABLE '$WPPREFIX'posts;' >> ~/log/clean-wp-db.log
$(which mysqlcheck) -o -vvv -u$WPUSER -p$WPPASS $WPDB &>> ~/log/clean-wp-db.log

echo; echo 'In case of an error, please look at the log file at ~/log/clean-wp-db.log'; echo
