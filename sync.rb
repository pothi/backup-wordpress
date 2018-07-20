# no longer used - keeping it for historical reason
# encoding: utf-8

# It is assumed that common mail settings are already in config.rb

# After the first sync,
# it is recommended to uploads only a particular year to save some CPU
# see example below

##
# Backup Generated: weekly_files_backups
# Once configured, you can run the backup with the following command:
#
# $ backup perform -t weekly_files_backups [-c <path_to_configuration_file>]
#
Backup::Model.new(:sync, 'Nightly Sync of uploads in domainname.com') do

  sync_with Cloud::S3 do |s3|
    s3.access_key_id     = "accesskeyid"
    s3.secret_access_key = "secretaccesskey"
    s3.region            = "us-east-1"
    s3.bucket            = "yourbucket"

    # For first sync
    s3.path              = "sync"
    # For yearly sync
    # s3.path              = "sync/uploads/"
    
    s3.mirror            = true
    # s3.concurrency_type  = :threads
    # s3.concurrency_level = 25
    s3.thread_count      = 10

    s3.directories do |directory|
        # For first sync
        directory.add "/home/client/sites/domainname.com/wordpress/wp-content/uploads/"
        # For yearly sync
        # directory.add "/home/client/sites/domainname.com/wordpress/wp-content/uploads/particularyear/"
    end

    s3.fog_options = {
        :path_style => true
    }
  end

  ##
  # Mail [Notifier]
  #
  # The default delivery method for Mail Notifiers is 'SMTP'.
  # See the Wiki for other delivery options.
  # https://github.com/meskyanichi/backup/wiki/Notifiers
  #
  notify_by Mail do |mail|
    mail.on_success           = false
    mail.on_warning           = false
    mail.on_failure           = true
  end

end

