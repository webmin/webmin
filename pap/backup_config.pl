
do 'pap-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local %iconfig = &foreign_config("inittab");
return ( $config{'pap_file'}, $config{'ppp_options'},
	 $config{'login_config'}, $config{'dialin_config'},
	 $iconfig{'inittab_file'},
	 grep { -r $_ } glob("$config{'ppp_options'}.*") );
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
return &apply_mgetty();
}

1;

