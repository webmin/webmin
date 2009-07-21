
do 'slp-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
return ( $config{'slpd_conf'}, $config{'slpd_reg'} );
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
if (&slpd_is_running()) {
	&restart();
	}
return undef;
}

1;

