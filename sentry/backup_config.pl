
do 'sentry-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
push(@rv, $config{'portsentry_config'})
	if (&has_command($config{'portsentry'}));
push(@rv, $config{'hostsentry_config'})
	if (-r $config{'hostsentry'});
push(@rv, $config{'logcheck'})
	if (&has_command($config{'logcheck'}));
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
if (&has_command($config{'portsentry'})) {
	# Re-start portsentry, if running
	local @pids = &get_portsentry_pids();
	if (@pids) {
		&stop_portsentry();
		local $err = &start_portsentry();
		return $err if ($err);
		}
	}
if (&has_command($config{'hostsentry'})) {
	# Re-start hostsentry, if running
	$pid = &get_hostsentry_pid();
	if ($pid) {
		&stop_hostsentry();
		local $err = &start_hostsentry();
                return $err if ($err);
		}
	}
return undef;
}

1;

