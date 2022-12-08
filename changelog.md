version: 5.0.0
    - date: 2022-12-08
    - Add user bin directories and snap bin to PATH.
    - a new common changelog.txt file.
    - mention the actual script name in the output / log.
    - migrate laravel and php backup scripts to their own repo.
    - remove redundant check for aws cli.
    - better documentation.

Before 5.0.0, separate changelogs were used.

db-backup.sh

version: 3.2.3
    - minor fixes
version: 3.2.2
    - date: 2022-11-29
    - rewrite logic while attempting to create required directories
    - add requirements section
version: 3.2.1
    - date: 2021-07-14
    - aws cli add option "--only-show-errors"
version: 3.2.0
    - date: 2021-03-27
    - improve naming scheme.
version: 3.1.1
    - date: 2020-11-24
    - improve documentation.

full-backup.sh

version: 4.0.3
    - multiple fixes
version: 4.0.2
    - date: 2022-11-29
    - rewrite logic while attempting to create required directories
    - add requirements section
version: 4.0.1
    - date: 2021-08-30
    - fix a minor bug
version: 4.0.0
    - date: 2021-06-06
    - simplify excludes in tar command
    - simplify naming scheme for encrypted backups
    - show only errors while uploading to S3. Not even progress bar.
version: 3.2.0
    - date: 2021-03-27
    - improve naming scheme.
changelog
version: 3.1.1
    - date: 2020-11-24
    - improve documentation
version: 3.1.0
    - delete old backups in $ENCRYPTED_BACKUP_PATH only if this directory / path exists


files-backup-without-uploads.sh

version: 3.1.2
    - date: 2022-11-29
    - rewrite logic while attempting to create required directories
v3.1.1
    - date: 2020-11-24
    - improve documentation
v2
    - date 2017-09-13
    - change of script name
    - change the output file name
    - remove older backups using a simple find command; props - @wpbullet
v1.1.2
    - date 2017-09-04
    - dynamically find the location of aws cli
v1.1.1
    - date 2017-09-03
    - change the default dir name from Backup to backups
    - no more syncing by default
v1.1
    - date 2017-05-05
    - moved to nightly backups
    - started excluding wp core files and uploads
    - uploads files are now synced, rather than taken as part of regular nightly backup
v1.0.4
    - date 2017-03-06
    - support for hard-coded variable AWS S3 Bucket Name
    - support for environment files (.envrc / .env)
    - skipped version 1.0.3
v1.0.2
    - date 2017-03-06
    - support for hard-coded variable $DOMAIN

