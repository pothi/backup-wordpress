Backup-Wordpress
================

Scripts to backup WordPress via server cron (cPanel, Plesk, etc)
----------------------------------------------------------------

There are plenty of plugins available to take backups within WordPress. However, the scripts mentioned here work outside WordPress making them much more effective and efficient. If you take offline backups, I highly recommend to use encryption and limit your offline storage to only allow [one-way backups](https://www.tinywp.com/write-only-backups-in-s3/).

## Features

- No plugin to install. So, no plugin conflicts!
- Single script to take backups of multiple sites.
- Separate script to take (nightly) files backup without uploads directory!
- Local and offline backups are supported.
- Automatic deletion of local backups.
- Support for sub-directory installation of WordPress!
- Support for simple encryption using GnuPG
- Alert via email when the offsite backup fails (and succeeds)

## Wishlist

- take only local backups or only remote backups or both.
- ability to remove local backups when taking only remote backups.
- single script to take all sorts of backups.
- close integration with wp-cli (probably as a plugin).
- alert when local storage reaches a limit.

## Requirements in the server

- wp-cli
- aws-cli and/or gsutil (optional, to take offline backups)
- SSH access
- mysqldump
- tar
- enough disk space to hold local backups
- [gpg](https://www.gnupg.org/index.html) for encrypted backups (optional, but helps to comply with GDPR).

## What does each backup script do?

- [db-backup.sh](https://github.com/pothi/backup-wordpress/blob/master/db-backup.sh) can take database backup with --add-drop-table option.
- [files-no-uploads-backup.sh](https://github.com/pothi/backup-wordpress/blob/master/files-no-uploads-backup.sh) can take files backups without uploads folder to reduce the overall size of the backup. Ideal for nightly backups!
- [full-backup.sh](https://github.com/pothi/backup-wordpress/blob/master/full-backup.sh) can take full backup including database (that is named db.sql and is available at the WordPress core directory). Ideal for a weekly routine!

## Where are the backups stored?

- local backups are stored in the directory named `~/backups/`. If it doesn't exist, the script/s would attempt to create it before execution.
- offline backups can be stored in AWS (for now). Support for other storage engines (especially for GCP) is coming soon!

## Usage

- You may configure most things on the command line since version 6.0.0. For usage, just run the script without arguments.
- If you use older version of the script (older than 6.0.00, firstly, go through each script and fill-in the variables to fit your particular environment. Currently, it is assumed that the WordPress core is available at `~/sites/example.com/public`.
- please adjust the number of days to keep the backup, depending on the remaining hard disk space in your server.
- test the scripts using SSH before implementing it in system cron.
- note: you may take backups of multiple domains like the following...

```
/path/to/db-backup.sh example1.com
/path/to/db-backup.sh example2.com
/path/to/db-backup.sh example3.com
```

For more usage options, please run `/path/to/db-backup.sh -h`.

The above is applicable to all the scripts!

## Contributors

Thanks to the following people who have contributed to this repo...

- [Nik](https://github.com/nik-lampe)
- [Francesco](https://github.com/Cicciodev)
- [Wischweh Mobile Consultancy](https://github.com/wischweh)

### How to decrypt, if I used a passphrase

`gpg --batch --passphrase your_passphrase encrypted_file.tar.gz.gpg`

### Can you implement it on my server?

Yes, of course. But, for a small fee of USD 5 per server per site. [Reach out to me now!](https://www.tinywp.in/contact/).

### I have a unique situation. Can you customize it to suit my particular environment?

Possibly, yes. My hourly rate is USD 50 per hour, though.

### Have questions or just wanted to say hi?

Please ping me on [Twitter](https://twitter.com/pothi) or [send me a message](https://www.tinywp.in/contact/).

Suggestions, bug reports, issues, forks are always welcome!
