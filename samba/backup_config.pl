
do 'samba-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'smb_conf'} );
push(@rv, $config{'smb_passwd'}) if ($config{'smb_passwd'});
&get_share("global");
local $umap = &getval("username map");
push(@rv, $umap) if ($umap);
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
return undef;
}

1;

