#!/usr/bin/env bash

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

version=6.4.0

### Variables - Please do not add trailing slash in the PATHs

# auto delete older backups after certain number days
# configurable using -k|--keepfor <days>
auto_delete_after=7

# where to store the database backups?
backup_path=${HOME}/backups/db-backups

# a passphrase for encryption, in order to being able to use almost any special characters use ""
# it's best to configure it in ~/.envrc file
passphrase=

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
sites_path=${HOME}/sites

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

log_file=${HOME}/log/db-backup.log
exec > >(tee -a "${log_file}")
exec 2> >(tee -a "${log_file}" >&2)

# Variables defined later in the script
script_name=$(basename "$0")
timestamp=$(date +%F_%H-%M-%S)
success_alert=
custom_email=
custom_wp_path=
bucket_name=
domain=
public_dir=public
size=
sizeH=

# get environment variables, if exists
# .envrc is in the following format
# export VARIABLE=value
[ -f "$HOME/.envrc" ] && source ~/.envrc
# uncomment the following, if you use .env with the format "VARIABLE=value" (without export)
# if [ -f "$HOME/.env" ]; then; set -a; source ~/.env; set +a; fi

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
      -b|--bucket) assert_argument "$1" "$opt"; bucket_name="$1"; shift;;
      -k|--keepfor) assert_argument "$1" "$opt"; auto_delete_after="$1"; shift;;
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
    domain=$1
    shift
else
    print_help
    exit 2
fi

# compatibility with old syntax to get bucket name
# To be removed in the future
if [ "$#" -gt 0 ]; then
    bucket_name=$1
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
if [ ! -d "$backup_path" ]; then
    if ! mkdir -p "$backup_path"; then
        echo "backup_path is not found at $backup_path. This script can't create it, either!"
        echo 'You may create it manually and re-run this script.'
        exit 1
    fi
fi

export PATH=~/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

command -q wp   || { echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; }
command -q aws  || { echo >&2 "[Warn]: aws cli is not found in \$PATH. Offsite backups will not be taken!"; }
command -q mail || echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

((auto_delete_after--))

# check for the variable/s in three places
# 1 - hard-coded value
# 2 - optional parameter while invoking the script
# 3 - environment files

alertEmail=${custom_email:-${BACKUP_ADMIN_EMAIL:-${ADMIN_EMAIL:-"root@localhost"}}}

# Define paths

# convert forward slash found in sub-directories to hyphen
# ex: example.com/test would become example.com-test
domain_full_path=$(echo "$domain" | awk '{gsub(/\//,"-")}; 1')

backup_name=${backup_path}/${domain_full_path}-db-${timestamp}.sql.gz
latest_backup=${backup_path}/${domain_full_path}-db-latest.sql.gz

# cPanel uses a different directory structure
# dir_to_backup and db_dump are used only in full-backup.sh
cPanel=$(/usr/local/cpanel/cpanel -V 2>/dev/null)
if [ "$cPanel" ]; then
    sites_path=$HOME
    public_dir=public_html
    wp_path=${sites_path}/${public_dir}
    # dir_to_backup=public_html
    # db_dump=${wp_path}/db.sql
else
    wp_path=${sites_path}/${domain}/${public_dir}
    # dir_to_backup=${domain}
    # db_dump=${sites_path}/${domain}/db.sql
fi

if [ "$custom_wp_path" ]; then
    wp_path="$custom_wp_path"
    backup_name=${custom_wp_path}/db.sql.gz
fi

[ -d "$wp_path" ] || { echo >&2 "WordPress is not found at ${wp_path}"; exit 1; }

echo "'$script_name' started on... $(date +%c)"

# take actual DB backup
# 2>/dev/null to suppress any warnings / errors
wp --path="${wp_path}" transient delete --all 2>/dev/null
if [ -n "$passphrase" ] ; then
    backup_name="${backup_name}".gpg
    wp --path="${wp_path}" db export --no-tablespaces=true --add-drop-table - | gzip | gpg --symmetric --passphrase "$passphrase" --batch -o "$backup_name"
else
    wp --path="${wp_path}" db export --no-tablespaces=true --add-drop-table - | gzip > "$backup_name"
fi
if [ "$?" = "0" ]; then
    printf "\nBackup is successfully taken locally."
else
    msg="$script_name - [Error] Something went wrong while taking local DB backup!"
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'DB Backup Failure' "$alertEmail"
    [ -f "$backup_name" ] && rm -f "$backup_name"
    exit 1
fi

size=$(du $backup_name | awk '{print $1}')
sizeH=$(du -h $backup_name | awk '{print $1}')

[ -L "$latest_backup" ] && rm "$latest_backup"
ln -s "$backup_name" "$latest_backup"

# send the backup offsite
if [ "$bucket_name" ]; then
    cmd="aws s3 cp $backup_name s3://$bucket_name/${domain_full_path}/db-backups/ --only-show-errors"
    if $cmd; then
        msg="Offsite backup successful."
        printf "\n%s\n\n" "$msg"
        [ "$success_alert" ] && echo "$script_name - $msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    else
        msg="$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    fi
fi

# Auto delete backups
find -L "$backup_path" -type f -mtime +$auto_delete_after -exec rm {} \;

echo "Database backup is done; please check the latest backup in '${backup_path}'."
echo "Latest backup is at ${backup_name}"
echo "Backup size: $size($sizeH)."

printf "Script ended on...%s\n\n" "$(date +%c)"

