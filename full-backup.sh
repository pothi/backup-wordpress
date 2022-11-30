#!/usr/bin/env bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

# Don't allow unset variables
# set -o nounset
# Exit if any command gives an error
# set -o errexit

# version: 4.0.2

# changelog
# version: 4.0.2
#   - date: 2022-11-29
#   - rewrite logic while attempting to create required directories
#   - add requirements section
# version: 4.0.1
#   - date: 2021-08-30
#   - fix a minor bug
# version: 4.0.0
#   - date: 2021-06-06
#   - simplify excludes in tar command
#   - simplify naming scheme for encrypted backups
#   - show only errors while uploading to S3. Not even progress bar.
# version: 3.2.0
#   - date: 2021-03-27
#   - improve naming scheme.
# changelog
# version: 3.1.1
#   - date: 2020-11-24
#   - improve documentation
# version: 3.1.0
#   - delete old backups in $ENCRYPTED_BACKUP_PATH only if this directory / path exists

# this script is basically
#   files-backup-without-uploads.sh script + part of db-backup.sh script
#   from files-backup-without-uploads.sh script, we do not exclude uploads directory - just removed the line from it

### Variables ###

# a passphrase for encryption, in order to being able to use almost any special characters use ""
PASSPHRASE=

# auto delete older backups after certain number days - default 30. YMMV
AUTODELETEAFTER=30

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

# if WP is in a sub-directory, please leave this empty!
# for cPanel, it is likely public_html
PUBLIC_DIR=public

### Variables
# You may hard-code the domain name and AWS S3 Bucket Name here
DOMAIN=
BUCKET_NAME=

#-------- Do NOT Edit Below This Line --------#

# attempt to create log directory if it doesn't exist
[ -d "${HOME}/log" ] || mkdir -p ${HOME}/log
if [ "$?" -ne 0 ]; then
    echo 'Log directory not found at ~/log'
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# attempt to create the backups directory, if it doesn't exist
[ -d "$BACKUP_PATH" ] || mkdir -p $BACKUP_PATH
if [ "$?" -ne 0 ]; then
    echo "BACKUP_PATH is not found at $BACKUP_PATH. The script can't create it, either!"
    echo 'You may create it manually and re-run this script.'
    exit 1
fi
# if passphrase is supplied, attempt to create backups directory for encrypt backups, if it doesn't exist
if [ -n "$PASSPHRASE" ]; then
    [ -d "$ENCRYPTED_BACKUP_PATH" ] || mkdir -p $ENCRYPTED_BACKUP_PATH
    if [ "$?" -ne 0 ]; then
        echo "ENCRYPTED_BACKUP_PATH Is not found at $ENCRYPTED_BACKUP_PATH. the script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

log_file=${HOME}/log/backups.log
exec > >(tee -a ${log_file} )
exec 2> >(tee -a ${log_file} >&2)

declare -r timestamp=$(date +%F_%H-%M-%S)
declare -r script_name=$(basename "$0")
declare -r aws_cli=$(which aws)
declare -r wp_cli=`which wp`

if [ -z "$wp_cli" ]; then
    echo "wp-cli is not found in $PATH. Exiting."
    exit 1
fi

if [ -z "$aws_cli" ]; then
    echo "aws-cli is not found in $PATH. Exiting."
    exit 1
fi

let AUTODELETEAFTER--

# get environment variables, if exists
[ -f "$HOME/.envrc" ] && source ~/.envrc
[ -f "$HOME/.env" ] && source ~/.env

# check for the variable/s in three places
# 1 - hard-coded value
# 2 - optional parameter while invoking the script
# 3 - environment files

if [ "$DOMAIN" == ""  ]; then
    if [ "$1" == "" ]; then
        if [ "$WP_DOMAIN" != "" ]; then
            DOMAIN=$WP_DOMAIN
        else
            echo "Usage $script_name example.com (S3 bucket name)"; exit 1
        fi
    else
        DOMAIN=$1
    fi
fi

if [ "$BUCKET_NAME" == ""  ]; then
    if [ "$2" != "" ]; then
        BUCKET_NAME=$2
    elif [ "$AWS_S3_BUCKET_NAME" != "" ]; then
        BUCKET_NAME=$AWS_S3_BUCKET_NAME
    fi
fi

echo "Script started on... $(date +%c)"

# path to backup
WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
[ ! -d "$WP_PATH" ] && echo "WordPress is not found at $WP_PATH" &&  exit 1

# path to be excluded from the backup
# no trailing slash, please
EXCLUDE_BASE_PATH=${DOMAIN}
if [ "$PUBLIC_DIR" != "" ]; then
    EXCLUDE_BASE_PATH=${EXCLUDE_BASE_PATH}/${PUBLIC_DIR}
fi

declare -a EXC_PATH
EXC_PATH[0]=${EXCLUDE_BASE_PATH}/.git
EXC_PATH[1]=${EXCLUDE_BASE_PATH}/wp-content/cache
# need more? - just use the above format
# all log files are excluded already.

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
    CURRENT_EXC_PATH=${EXC_PATH[$i]}
    EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
    # remember the trailing space; we'll use it later
done

#------------- from db-script.sh --------------#
DB_OUTPUT_FILE_NAME=${SITES_PATH}/${DOMAIN}/db.sql

# to capture non-zero exit code in the pipeline
set -o pipefail

# take actual DB backup
$wp_cli --path=${WP_PATH} transient delete --all
$wp_cli --path=${WP_PATH} db export --no-tablespaces=true --add-drop-table $DB_OUTPUT_FILE_NAME
if [ "$?" != "0" ]; then
    echo; echo '[Warn] Something went wrong while taking DB backup!'
    # remove the empty backup file
    rm -f $DB_OUTPUT_FILE_NAME &> /dev/null
fi
#------------- end of snippet from db-script.sh --------------#

FULL_BACKUP_FILE_NAME=${BACKUP_PATH}/${DOMAIN}-$timestamp.tar.gz
LATEST_FULL_BACKUP_FILE_NAME=${BACKUP_PATH}/${DOMAIN}-latest.tar.gz

if [ ! -z "$PASSPHRASE" ]; then
    FULL_BACKUP_FILE_NAME=${FULL_BACKUP_FILE_NAME}.gpg
    LATEST_FULL_BACKUP_FILE_NAME=${LATEST_FULL_BACKUP_FILE_NAME}.gpg
    # using symmetric encryption
    # option --batch to avoid passphrase prompt
    # encrypting database dump
    tar hcz -C ${SITES_PATH} --exclude='*.log' ${EXCLUDES} ${DOMAIN} | gpg --symmetric --passphrase $PASSPHRASE --batch -o $FULL_BACKUP_FILE_NAME
else
    echo "[Warn] No passphrase provided for encryption!"
    echo "[Warn] If you are from Europe, please check GDPR compliance."
    tar hczf ${FULL_BACKUP_FILE_NAME} -C ${SITES_PATH} ${EXCLUDES} ${DOMAIN} &> /dev/null
fi
if [ "$?" != "0" ]; then
    echo; echo 'Something went wrong while taking full backup'; echo
    echo "Check $log_file for any log info"; echo
else
    echo; echo 'Backup is successfully taken locally.'; echo
fi

[ -L $LATEST_FULL_BACKUP_FILE_NAME ] && rm $LATEST_FULL_BACKUP_FILE_NAME
ln -s ${FULL_BACKUP_FILE_NAME} $LATEST_FULL_BACKUP_FILE_NAME

# remove the reduntant DB backup
rm $DB_OUTPUT_FILE_NAME

# send backup to AWS S3 bucket
if [ "$BUCKET_NAME" != "" ]; then
    if [ ! -e "$aws_cli" ]; then
        echo "[Warn] aws-cli is not found in \$PATH. Exiting."
        echo "PATH: $PATH"
        echo "AWS Bucket Name: '$BUCKET_NAME'."
        exit 1
    fi

    $aws_cli s3 cp ${FULL_BACKUP_FILE_NAME} s3://$BUCKET_NAME/${DOMAIN}/full-backups/ --only-show-errors

    if [ "$?" != "0" ]; then
        echo; echo '[Warn] Something went wrong while taking offsite backup.'; echo
        echo "Check $log_file for any log info"; echo
    else
        echo; echo 'Offsite backup successful.'; echo
    fi
fi

# Auto delete backups 
find $BACKUP_PATH -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo 'Full backup is done; please check the latest backup in '${BACKUP_PATH}'.';
echo "Latest backup is at ${FULL_BACKUP_FILE_NAME}"

echo "Script ended on... $(date +%c)"
echo
