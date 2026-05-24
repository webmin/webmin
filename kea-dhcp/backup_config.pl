
use strict;
use warnings;
require 'kea-dhcp-lib.pl';    ## no critic

# backup_config_files()
# Returns files that can be backed up.
sub backup_config_files
{
return &get_all_config_files();
}

# pre_backup()
# Runs before Webmin backs up Kea configuration files.
sub pre_backup
{
# No pre-backup daemon action is needed; Kea configs are ordinary files.
return;
}

# post_backup()
# Runs after Webmin completes a Kea configuration backup.
sub post_backup
{
# Backups are read-only, so leave running services untouched.
return;
}

# pre_restore()
# Runs before Webmin restores Kea configuration files.
sub pre_restore
{
# Restore writes happen before service reload, so there is nothing to prepare.
return;
}

# post_restore()
# Runs after Webmin restores Kea configuration files.
sub post_restore
{
# If Kea was active before restore, reload it so restored files take effect.
return &kea_run_action('restart') if (&kea_running_pids());
return;
}

1;
