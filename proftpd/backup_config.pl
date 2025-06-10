
do 'proftpd-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local $conf = &get_config();
local @rv = map { $_->{'file'} } @$conf;
return &unique(@rv);
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
return undef if ($inet);
local $pid = &get_proftpd_pid();
if ($pid) {
	&kill_logged('HUP', $pid);
	}
return undef;
}

1;

