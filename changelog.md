version: 6.2.2
    - date: 2023-07-17
    - better user output.

version: 6.2.1
    - date: 2023-07-12
    - check for log directory earlier.

version: 6.2.0
    - date: 2023-07-05
    - display the size of the backup in the console output

version: 6.1.2
    - date: 2023-05-22
    - exclude zip and gz along with log files in full / files backups.
    - improve docs

version: 6.1.1
    - date: 2023-02-21
    - fix a major bug while taking files backup.
    - introduce debug variable to print important values.
    - suppress warnings in the output of wp transient delete.
    - remove sourcing ~/.env
    - improve docs

version: 6.0.3
    - date: 2023-02-20
    - improve docs

version: 6.0.0
    - date: 2023-02-16
    - pass important variables as arguments. No breaking changes. Old usage format still works.
    - change the default location of DB backup inside a full backup
    - fix and simplify excludes in full backup.

version: 5.3.0
    - date: 2023-02-03
    - alert upon success

version: 5.2.1
    - date: 2023-01-13
    - show stderr for tar

version: 5.2.0
    - date: 2023-01-04
    - Reduce the default number of days to keep the backups

version: 5.1.0
    - date: 2022-12-21
    - Add support for cPanel (main site).
    - Change naming scheme for DB backups.
    - Simplify logics.

version: 5.0.0
    - date: 2022-12-08
    - Add user bin directories and snap bin to PATH.
    - a new common changelog.txt file.
    - mention the actual script name in the output / log.
    - migrate laravel and php backup scripts to their own repo.
    - remove redundant check for aws cli.
    - better documentation.

-----------------------------------------------------------------------------

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

