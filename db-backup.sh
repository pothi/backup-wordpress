#!/usr/bin/env bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

version=6.0.3

### Variables - Please do not add trailing slash in the PATHs

# auto delete older backups after certain number days
# configurable using -k|--keepfor <days>
AUTODELETEAFTER=7

# where to store the database backups?
BACKUP_PATH=${HOME}/backups/db-backups

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
script_name=$(basename "$0")
timestamp=$(date +%F_%H-%M-%S)
success_alert=
custom_email=
custom_wp_path=
BUCKET_NAME=
DOMAIN=
PUBLIC_DIR=public

# get environment variables, if exists
[ -f "$HOME/.envrc" ] && source ~/.envrc
[ -f "$HOME/.env" ] && source ~/.env

print_help() {
    printf '%s\n\n' "Take a database backup"

    printf 'Usage: %s [-b <name>] [-k <days>] [-e <email-address>] [-s] [-p <WP path>] [-v] [-h] example.com\n\n' "$script_name"

    printf '\t%s\t%s\n' "-b, --bucket" "Name of the bucket for offsite backup (default: none)"
    printf '\t%s\t%s\n' "-k, --keepfor" "# of days to keep the local backups (default: 7)"
    printf '\t%s\t%s\n' "-e, --email" "Email to send success/failures alerts (default: root@localhost)"
    printf '\t%s\t%s\n' "-s, --success" "Alert on successful backup too (default: alert only on failures)"
    printf '\t%s\t%s\n' "-p, --path" "Path to WP files (default: ~/sites/example.com/public or ~/public_html for cPanel)"
    printf '\t%s\t%s\n' "-v, --version" "Prints the version info"
    printf '\t%s\t%s\n' "-h, --help" "Prints help"

    printf "\nFor more info, changelog and documentation... https://github.com/pothi/backup-wordpress\n"
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

command -v wp >/dev/null || { echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; }
command -v aws >/dev/null || { echo >&2 "[Warn]: aws cli is not found in \$PATH. Offsite backups will not be taken!"; }
command -v mail >/dev/null || echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

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
    WP_PATH=${SITES_PATH}/${PUBLIC_DIR}
    # dir_to_backup=public_html
    # db_dump=${WP_PATH}/db.sql
else
    WP_PATH=${SITES_PATH}/${DOMAIN}/${PUBLIC_DIR}
    # dir_to_backup=${DOMAIN}
    # db_dump=${SITES_PATH}/${DOMAIN}/db.sql
fi

if [ "$custom_wp_path" ]; then
    WP_PATH="$custom_wp_path"
    DB_OUTPUT_FILE_NAME=${custom_wp_path}/db.sql
fi

[ -d "$WP_PATH" ] || { echo >&2 "WordPress is not found at ${WP_PATH}"; exit 1; }

echo "'$script_name' started on... $(date +%c)"

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
DOMAIN_FULL_PATH=$(echo "$DOMAIN" | awk '{gsub(/\//,"-")}; 1')

DB_OUTPUT_FILE_NAME=${BACKUP_PATH}/${DOMAIN_FULL_PATH}-${timestamp}.sql.gz
DB_LATEST_FILE_NAME=${BACKUP_PATH}/${DOMAIN_FULL_PATH}-latest.sql.gz

# take actual DB backup
wp --path="${WP_PATH}" transient delete --all
if [ -n "$PASSPHRASE" ] ; then
    DB_OUTPUT_FILE_NAME="${DB_OUTPUT_FILE_NAME}".gpg
    wp --path="${WP_PATH}" db export --no-tablespaces=true --add-drop-table - | gzip | gpg --symmetric --passphrase "$PASSPHRASE" --batch -o "$DB_OUTPUT_FILE_NAME"
else
    wp --path="${WP_PATH}" db export --no-tablespaces=true --add-drop-table - | gzip > "$DB_OUTPUT_FILE_NAME"
fi
if [ "$?" = "0" ]; then
    printf "\nBackup is successfully taken locally.\n\n"
else
    msg="$script_name - [Error] Something went wrong while taking local DB backup!"
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'DB Backup Failure' "$alertEmail"
    [ -f "$DB_OUTPUT_FILE_NAME" ] && rm -f "$DB_OUTPUT_FILE_NAME"
    exit 1
fi

[ -L "$DB_LATEST_FILE_NAME" ] && rm "$DB_LATEST_FILE_NAME"
ln -s "$DB_OUTPUT_FILE_NAME" "$DB_LATEST_FILE_NAME"

# send the backup offsite
if [ "$BUCKET_NAME" ]; then
    cmd="aws s3 cp $DB_OUTPUT_FILE_NAME s3://$BUCKET_NAME/${DOMAIN_FULL_PATH}/db-backups/ --only-show-errors"
    if $cmd; then
        msg="$script_name - Offsite backup successful."
        printf "\n%s\n\n" "$msg"
        [ "$success_alert" ] && echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    else
        msg="$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    fi
fi

# Auto delete backups
find -L "$BACKUP_PATH" -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo "Database backup is done; please check the latest backup in '${BACKUP_PATH}'."
echo "Latest backup is at ${DB_OUTPUT_FILE_NAME}"

printf "Script ended on...%s\n\n" "$(date +%c)"

