
do 'init-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
if ($config{'init_base'}) {
	local $a;
	foreach $a (&list_actions()) {
		local @ac = split(/\s+/, $a);
		push(@rv, $ac[0] =~ /^\// ? $ac[0]
					  : "$config{'init_dir'}/$ac[0]");
		if ($config{'daemons_dir'} &&
		    -r "$config{'daemons_dir'}/$ac[0]") {
			push(@rv, "$config{'daemons_dir'}/$ac[0]");
			}
		local $ufile = "/etc/init/$ac[0]";
		if (-r $ufile) {
			push(@rv, $ufile);
			}
		}
	}
else {
	# Just bootup and shutdown scripts
	push(@rv, $config{'local_script'});
	push(@rv, $config{'local_down'}) if ($config{'local_down'});
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
}

1;

