
do 'majordomo-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;

# Add main config file
local $conf = &get_config();
push(@rv, $config{'majordomo_cf'});

# Add all lists
local $list;
foreach $list (&list_lists($conf)) {
	local $linfo = &get_list($list, $conf);
	push(@rv, $linfo->{'members'});
	push(@rv, $linfo->{'config'});
	push(@rv, $linfo->{'info'});
	push(@rv, $linfo->{'intro'});
	}

# Add aliases file
local $afiles = &get_aliases_file();
push(@rv, @$afiles);

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

