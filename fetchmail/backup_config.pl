
do 'fetchmail-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
if ($config{'config_file'}) {
	push(@rv, $config{'config_file'});
	}
else {
	setpwent();
	while(@uinfo = getpwent()) {
		local $path = "$uinfo[7]/.fetchmailrc";
		push(@rv, $path) if (-r $path);
		}
	endpwent() if ($gconfig{'os_type'} ne 'hpux');
	}
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
return undef;
}

1;

