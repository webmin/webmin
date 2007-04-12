
do 'wuftpd-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
foreach $f ("ftpaccess", "ftpconversions", "ftpgroups", "ftphosts", "ftpusers"){
	push(@rv, $config{$f}) if ($config{$f});
	}
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
local ($inet, $inet_mod) = &running_under_inetd();
if (!$inet) {
	local $pid = &check_pid_file($config{'pid_file'});
	if ($pid) {
		&kill_logged('TERM', $in{'pid'});
		&system_logged("$config{'ftpd_path'} -l -a -S >/dev/null 2>&1 </dev/null");
		}
	}
return undef;
}

1;

