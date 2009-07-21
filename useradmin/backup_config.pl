
do 'user-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
foreach $f ("passwd_file", "group_file", "shadow_file", "master_file",
	    "gshadow_file") {
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
&making_changes();
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
&made_changes();
return undef;
}

1;

