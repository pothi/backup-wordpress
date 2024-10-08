#!/usr/bin/env bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

version=6.4.0

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

# To debug, use any value for "debug", otherwise please leave it empty
debug=

#-------- Do NOT Edit Below This Line --------#

[ "$debug" ] && set -x

# attempt to create log directory if it doesn't exist
if [ ! -d "${HOME}/log" ]; then
    if ! mkdir -p "${HOME}"/log; then
        echo "Log directory not found at ~/log. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

log_file=${HOME}/log/full-backup.log
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
size=
sizeH=

# get environment variables, if exists
# .envrc is in the following format
# export VARIABLE=value
[ -f "$HOME/.envrc" ] && source ~/.envrc
# uncomment the following, if you use .env with the format "VARIABLE=value" (without export)
# if [ -f "$HOME/.env" ]; then; set -a; source ~/.env; set +a; fi

# printf 'Usage: %s [-b|--bucket <name>] [-k|--keepfor <days>] [-e|--email <email-address>] [-p|--path <WP path>] [-v|--version] [-h|--help] example.com\n' "$0"
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

# attempt to create the backups directory, if it doesn't exist
if [ ! -d "$BACKUP_PATH" ]; then
    if ! mkdir -p "$BACKUP_PATH"; then
        echo "BACKUP_PATH is not found at $BACKUP_PATH. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

export PATH=~/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

command -q wp   || { echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; }
command -q aws  || { echo >&2 "[Warn]: aws cli is not found in \$PATH. Offsite backups will not be taken!"; }
command -q mail || echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

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

[ -d "$WP_PATH" ] || { echo >&2 "WordPress is not found at ${WP_PATH}"; exit 1; }

echo "'$script_name' started on... $(date +%c)"

# path to be excluded from the backup
# no trailing slash, please
exclude_base_path=${DOMAIN}/${PUBLIC_DIR}

declare -a EXC_PATH
EXC_PATH[0]='*.log'
EXC_PATH[1]='*.gz'
EXC_PATH[2]='*.zip'
EXC_PATH[3]=${exclude_base_path}/.git
EXC_PATH[4]=${exclude_base_path}/wp-content/cache
EXC_PATH[5]=${exclude_base_path}/wp-content/wflogs
EXC_PATH[5]=${exclude_base_path}/wp-content/litespeed
EXC_PATH[6]='*.sql'
# need more? - just use the above format
# EXC_PATH[7]=${exclude_base_path}/wp-content/uploads

EXCLUDES=''
for i in "${!EXC_PATH[@]}" ; do
    CURRENT_EXC_PATH=${EXC_PATH[$i]}
    EXCLUDES=${EXCLUDES}'--exclude='$CURRENT_EXC_PATH' '
    # remember the trailing space; we'll use it later
done

if [ "$debug" ]; then
    echo "exclude_base_path: $exclude_base_path"
    printf "EXC_PATH: %s\n" "${EXC_PATH[@]}"
    echo "EXCLUDES: $EXCLUDES"

    # exit
fi

#------------- from db-script.sh --------------#
# take actual DB backup
# 2>/dev/null to suppress any warnings / errors
wp --path="${WP_PATH}" transient delete --all
if ! wp --path="${WP_PATH}" db export --no-tablespaces=true --add-drop-table "$db_dump"; then
    msg="$script_name - [Error] Something went wrong while taking DB dump!"
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'DB Dump Failure' "$alertEmail"
    # remove the empty backup file
    [ -f "$db_dump" ] && rm "$db_dump"
    exit 1
fi
#------------- end of snippet from db-script.sh --------------#

BACKUP_NAME=${BACKUP_PATH}/${DOMAIN}-full-$timestamp.tar.gz
LATEST_BACKUP=${BACKUP_PATH}/${DOMAIN}-full-latest.tar.gz

if [ "$PASSPHRASE" ]; then
    BACKUP_NAME=${BACKUP_NAME}.gpg
    LATEST_BACKUP=${LATEST_BACKUP}.gpg
    # using symmetric encryption
    # option --batch to avoid passphrase prompt
    tar hcz -C "${SITES_PATH}" ${EXCLUDES} "${dir_to_backup}" | gpg --symmetric --passphrase "$PASSPHRASE" --batch -o "$BACKUP_NAME"
else
    echo "[Warn] No passphrase provided for encryption!"
    echo "[Warn] If you are from Europe, please check GDPR compliance."
    # tar hczf ${BACKUP_NAME} --warning=no-file-changed ${EXCLUDES} -C ${SITES_PATH} ${dir_to_backup} > /dev/null
    tar hczf "${BACKUP_NAME}" ${EXCLUDES} -C "${SITES_PATH}" "${dir_to_backup}" > /dev/null
fi
if [ "$?" = "0" ]; then
    printf "\nBackup is successfully taken locally.\n\n"
else
    msg="$script_name - [Warn] Something went wrong while taking local backup."
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'Full backup may have failed!' "$alertEmail"
    # Do not exit as tar exists with error code 1 even under certain warnings
    # exit 1
fi

size=$(du $BACKUP_NAME | awk '{print $1}')
sizeH=$(du -h $BACKUP_NAME | awk '{print $1}')

# Remove the old link to latest backup and update it to the current backup file.
[ -L "$LATEST_BACKUP" ] && rm "$LATEST_BACKUP"
ln -s "${BACKUP_NAME}" "$LATEST_BACKUP"

# remove the temporary DB dump
[ -f "$db_dump" ] && rm "$db_dump"

# send backup to AWS S3 bucket
if [ "$BUCKET_NAME" != "" ]; then
    cmd="aws s3 cp ${BACKUP_NAME} s3://$BUCKET_NAME/${DOMAIN}/full-backups/ --only-show-errors"

    if $cmd; then
        msg="Offsite backup successful. Backup size: $size($sizeH)"
        printf "\n%s\n\n" "$msg"
        [ "$success_alert" ] && echo "$script_name - $msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    else
        msg="$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    fi
fi

# Auto delete backups
find -L "$BACKUP_PATH" -type f -mtime +$AUTODELETEAFTER -exec rm {} \;

echo "Full backup is done; please check the latest backup in '${BACKUP_PATH}'."
echo "Latest backup is at ${BACKUP_NAME}"
echo "Backup size: $size($sizeH)."

printf "Script ended on...%s\n\n" "$(date +%c)"
