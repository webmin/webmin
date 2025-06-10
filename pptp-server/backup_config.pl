
do 'pptp-server-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local $conf = &get_config();
local $option = &find_conf("option", $conf);
$option ||= $config{'ppp_options'};
return ( $config{'file'}, $config{'pap_file'}, $option );
}

# pre_backup(&files)
# Called before the files are actually read
sub pre_backup
{
return undef;
}

# post_backup(&files)
# Called after the files are actually read
sub post_backup
{
return undef;
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
return &apply_configuration();
}

1;

