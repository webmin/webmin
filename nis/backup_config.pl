
do 'nis-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'client_conf'}, $config{'nsswitch_conf'},
	      $ypserv_conf, $yp_makefile, $config{'securenets'} );
local $t;
foreach $t (&list_nis_tables()) {
	push(@rv, @{$t->{'files'}});
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
&apply_table_changes() if (!$config{'manual_build'});
return undef;
}

1;

