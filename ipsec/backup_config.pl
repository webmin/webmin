
do 'ipsec-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'file'}, $config{'secrets'} );
push(@rv, map { "$config{'policies_dir'}/$_" } &list_policies());
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
return &restart_ipsec();
}

1;

