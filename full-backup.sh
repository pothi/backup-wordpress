#!/usr/bin/env bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

version=6.0.0

# this script is basically
#   files-backup-without-uploads.sh script + part of db-backup.sh script
#   from files-backup-without-uploads.sh script, we do not exclude uploads directory - just removed the line from it

### Variables ###

# auto delete older backups after certain number days
# configurable using -k|--keepfor <days>
AUTODELETEAFTER=7

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/full-backups

# a passphrase for encryption, in order to being able to use almost any special characters use ""
# it's best to configure it in ~/.envrc file
PASSPHRASE=

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
SITES_PATH=${HOME}/sites

#-------- Do NOT Edit Below This Line --------#

log_file=${HOME}/log/backups.log
exec > >(tee -a "${log_file}")
exec 2> >(tee -a "${log_file}" >&2)

# Variables defined later in the script
success_alert=
custom_email=
custom_wp_path=
BUCKET_NAME=
DOMAIN=
PUBLIC_DIR=public

# get environment variables, if exists
[ -f "$HOME/.envrc" ] && source ~/.envrc
[ -f "$HOME/.env" ] && source ~/.env

# printf 'Usage: %s [-b|--bucket <name>] [-k|--keepfor <days>] [-e|--email <email-address>] [-p|--path <WP path>] [-v|--version] [-h|--help] example.com\n' "$0"
print_help() {
    printf '%s\n' "Take a full backup - DB and files"
    echo
    printf 'Usage: %s [-b <name>] [-k <days>] [-e <email-address>] [-s] [-p <WP path>] [-v] [-h] example.com\n' "$0"
    echo
    printf '\t%s\t%s\n' "-b, --bucket" "Name of the bucket for offsite backup (default: none)"
    printf '\t%s\t%s\n' "-k, --keepfor" "# of days to keep the local backups (default: 7)"
    printf '\t%s\t%s\n' "-e, --email" "Email to send success/failures alerts (default: root@localhost)"
    printf '\t%s\t%s\n' "-s, --success" "Alert on successful backup too (default: alert only on failures)"
    printf '\t%s\t%s\n' "-p, --path" "Path to WP files (default: ~/sites/example.com/public or ~/public_html for cPanel)"
    echo
    printf '\t%s\t%s\n' "-v, --version" "Prints the version info"
    printf '\t%s\t%s\n' "-h, --help" "Prints help"

    echo
    echo "For more info, changelog and documentation... https://github.com/pothi/backup-wordpress"
}

# https://stackoverflow.com/a/62616466/1004587
# Convenience functions.
EOL=$(printf '\1\3\3\7')
opt=
usage_error () { echo >&2 "$(basename $0):  $1"; exit 2; }
assert_argument () { test "$1" != "$EOL" || usage_error "$2 requires an argument"; }

# One loop, nothing more.
if [ "$#" != 0 ]; then
  set -- "$@" "$EOL"
  while [ "$1" != "$EOL" ]; do
    opt="$1"; shift
    case "$opt" in

      # Your options go here.
      -v|--version) echo $version; exit 0;;
      -V) echo $version; exit 0;;
      -h|--help) print_help; exit 0;;
      -b|--bucket) assert_argument "$1" "$opt"; BUCKET_NAME="$1"; shift;;
      -k|--keepfor) assert_argument "$1" "$opt"; AUTODELETEAFTER="$1"; shift;;
      -p|--path) assert_argument "$1" "$opt"; custom_wp_path="$1"; shift;;
      -e|--email) assert_argument "$1" "$opt"; custom_email="$1"; shift;;
      -s|--success) success_alert=1;;

      # Arguments processing. You may remove any unneeded line after the 1st.
      -|''|[!-]*) set -- "$@" "$opt";;                                          # positional argument, rotate to the end
      --*=*)      set -- "${opt%%=*}" "${opt#*=}" "$@";;                        # convert '--name=arg' to '--name' 'arg'
      -[!-]?*)    set -- $(echo "${opt#-}" | sed 's/\(.\)/ -\1/g') "$@";;       # convert '-abc' to '-a' '-b' '-c'
      --)         while [ "$1" != "$EOL" ]; do set -- "$@" "$1"; shift; done;;  # process remaining arguments as positional
      -*)         usage_error "unknown option: '$opt'";;                        # catch misspelled options
      *)          usage_error "this should NEVER happen ($opt)";;               # sanity test for previous patterns

    esac
  done
  shift  # $EOL
fi

# Do something cool with "$@"... \o/

# Get example.com
if [ "$#" -gt 0 ]; then
    DOMAIN=$1
    shift
else
    print_help
    exit 2
fi

# compatibility with old syntax to get bucket name
# To be removed in the future
if [ "$#" -gt 0 ]; then
    BUCKET_NAME=$1
    echo "You are using old syntax."
    print_help
    shift
fi

# unwanted argument/s
if [ "$#" -gt 0 ]; then
    print_help
    exit 2
fi

# to capture non-zero exit code in the pipeline
set -o pipefail

# attempt to create log directory if it doesn't exist
if [ ! -d "${HOME}/log" ]; then
    if ! mkdir -p "${HOME}"/log; then
        echo "Log directory not found at ~/log. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi
# attempt to create the backups directory, if it doesn't exist
if [ ! -d "$BACKUP_PATH" ]; then
    if ! mkdir -p "$BACKUP_PATH"; then
        echo "BACKUP_PATH is not found at $BACKUP_PATH. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

export PATH=~/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

timestamp=$(date +%F_%H-%M-%S)
script_name=$(basename "$0")

command -v wp >/dev/null || { echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; }
command -v aws >/dev/null || { echo >&2 "aws cli is not found in $PATH. Exiting."; exit 1; }
command -v mail >/dev/null || echo >&2 "[WARNING]: 'mail' command is not found in $PATH; Alerts will not be sent!"

((AUTODELETEAFTER--))

# check for the variable/s in three places
# 1 - hard-coded value
# 2 - optional parameter while invoking the script
# 3 - environment files

alertEmail=${custom_email:-${BACKUP_ADMIN_EMAIL:-${ADMIN_EMAIL:-"root@localhost"}}}

# Define paths
# cPanel uses a different directory structure
# dir_to_backup and db_dump are used only in full-backup.sh
cPanel=$(/usr/local/cpanel/cpanel -V 2>/dev/null)
if [ "$cPanel" ]; then
    SITES_PATH=$HOME
    PUBLIC_DIR=public_html
    dir_to_backup=public_html
    db_dump=${WP_PATH}/db.sql
    WP_PATH=${SITES_PATH}/${PUBLIC_DIR}
else
    dir_to_backup=${DOMAIN}
    db_dump=${SITES_PATH}/${DOMAIN}/db.sql
    WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
fi

if [ "$custom_wp_path" ]; then
    WP_PATH="$custom_wp_path"
    db_dump=${custom_wp_path}/db.sql
fi

[ ! -d "$WP_PATH" ] && echo "WordPress is not found at $WP_PATH" &&  exit 1

echo "'$script_name' started on... $(date +%c)"

# path to be excluded from the backup
# no trailing slash, please
exclude_base_path=${DOMAIN}/${PUBLIC_DIR}

declare -a EXC_PATH
EXC_PATH[0]='*.log'
EXC_PATH[1]=${exclude_base_path}/.git
EXC_PATH[2]=${exclude_base_path}/wp-content/cache
# need more? - just use the above format
# EXC_PATH[3]=${exclude_base_path}/wp-content/uploads

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
    CURRENT_EXC_PATH=${EXC_PATH[$i]}
    EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
    # remember the trailing space; we'll use it later
done

#------------- from db-script.sh --------------#
# take actual DB backup
wp --path="${WP_PATH}" transient delete --all
if ! wp --path="${WP_PATH}" db export --no-tablespaces=true --add-drop-table "$db_dump"; then
    msg='[Error] Something went wrong while taking DB dump!'
    echo; echo "$msg"; echo
    echo "$msg" | mail -s 'DB Dump Failure' "$alertEmail"
    # remove the empty backup file
    [ -f "$db_dump" ] && rm "$db_dump"
    exit 1
fi
#------------- end of snippet from db-script.sh --------------#

FULL_BACKUP_FILE_NAME=${BACKUP_PATH}/${DOMAIN}-$timestamp.tar.gz
LATEST_FULL_BACKUP_FILE_NAME=${BACKUP_PATH}/${DOMAIN}-latest.tar.gz

if [ "$PASSPHRASE" ]; then
    FULL_BACKUP_FILE_NAME=${FULL_BACKUP_FILE_NAME}.gpg
    LATEST_FULL_BACKUP_FILE_NAME=${LATEST_FULL_BACKUP_FILE_NAME}.gpg
    # using symmetric encryption
    # option --batch to avoid passphrase prompt
    tar hcz "${EXCLUDES}" -C "${SITES_PATH}" "${dir_to_backup}" | gpg --symmetric --passphrase "$PASSPHRASE" --batch -o "$FULL_BACKUP_FILE_NAME"
else
    echo "[Warn] No passphrase provided for encryption!"
    echo "[Warn] If you are from Europe, please check GDPR compliance."
    # tar hczf ${FULL_BACKUP_FILE_NAME} --warning=no-file-changed ${EXCLUDES} -C ${SITES_PATH} ${dir_to_backup} > /dev/null
    tar hczf "${FULL_BACKUP_FILE_NAME}" "${EXCLUDES}" -C "${SITES_PATH}" "${dir_to_backup}" > /dev/null
fi
if [ "$?" != "0" ]; then
    msg='[Warn] Something went wrong while taking a full backup. Please see the logs for more info!'
    echo; echo "$msg"; echo
    echo "$msg" | mail -s 'Full backup may have failed!' "$alertEmail"
    # Do not exit as tar exists with error code 1 even under certain warnings
    # exit 1
else
    echo; echo 'Backup is successfully taken locally.'; echo
fi

# Remove the old link to latest backup and update it to the current backup file.
[ -L "$LATEST_FULL_BACKUP_FILE_NAME" ] && rm "$LATEST_FULL_BACKUP_FILE_NAME"
ln -s "${FULL_BACKUP_FILE_NAME}" "$LATEST_FULL_BACKUP_FILE_NAME"

# remove the temporary DB dump
[ -f "$db_dump" ] && rm "$db_dump"

# send backup to AWS S3 bucket
if [ "$BUCKET_NAME" != "" ]; then
    cmd="aws s3 cp ${FULL_BACKUP_FILE_NAME} s3://$BUCKET_NAME/${DOMAIN}/full-backups/ --only-show-errors"

    if $cmd; then
        msg='Offsite backup successful.'
        echo; echo "$msg"; echo
        [ "$success_alert" ] && echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    else
        msg='[Error] Something went wrong while taking offsite backup.'
        echo; echo "$msg"; echo
        echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    fi
fi

# Auto delete backups
find -L "$BACKUP_PATH" -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo "Full backup is done; please check the latest backup in '${BACKUP_PATH}'."
echo "Latest backup is at ${FULL_BACKUP_FILE_NAME}"

echo "Script ended on... $(date +%c)"
echo
