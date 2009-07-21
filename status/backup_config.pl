
do 'status-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @servs = &list_services();
local @rv = map { $_->{'_file'} } @servs;
push(@rv, $module_config_file);
push(@rv, map { $_->{'_file'} } &list_templates());
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
%config = ( );
&read_file($module_config_file, \%config);
&setup_cron_job();
return undef;
}

1;

