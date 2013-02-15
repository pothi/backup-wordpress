Backup-Wordpress - Scripts to backup WordPress via (cPanel / Plesk) cron
========================================================================

There are plenty of plugins available to take backups within WordPress. However, this works outside WordPress. So, no conflicts with other plugins. :) Additionally, as these scripts work outside WordPress, there is no performance lag while running via cron.

How to Implement it in cPanel
-----------------------------

1. Create a folder named 'backups' in '/home/username/' folder. So, once, this folder is created the contents of the '/home/username/' would look something like this...
* .cpanel
* .trash
* backups
* etc
* perl5
* public_ftp
* public_html
2. Create the following two folders in '/home/username/backups/'
* databases
* files
3. Upload the following two files in '/home/username/backups/'
* databack-backup_nightly.sh
* files-backup_weekly.sh
4. Edit those newly uploaded files to fit your specific site / configuration
5. Create two cron jobs in cPanel with the following commands
* $(which bash) /home/username/backups/files-backup_weekly.sh >/dev/null 2>&1
* $(which bash) /home/username/backups/database-backup_nightly.sh >/dev/null 2>&1
6. The above commands can be executed in whatever the schedule you like. As the name suggestion, you can run...
* files-backup_weekly.sh on a weekly schedule
* database-backup_nightly.sh on a nightly schedule

Suggestions, bug reports, issues, forks are always welcome!

Have Questions?
Contact me (pothi) at https://www.tinywp.in/contact/
