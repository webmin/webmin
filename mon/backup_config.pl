
do 'mon-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
push(@rv, $mon_config_file);
push(@rv, &mon_users_file());
push(@rv, &mon_auth_file());
return @rv;
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
if (&check_pid_file($config{'pid_file'})) {
	return &restart_mon();
	}
return undef;
}

1;

