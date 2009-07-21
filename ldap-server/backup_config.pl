
do 'ldap-server-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
if (&local_ldap_server() == 1) {
	push(@rv, $config{'config_file'});
	push(@rv, map { $_->{'file'} } &list_schema_files());
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
if (&local_ldap_server() == 1) {
	return &apply_configuration();
	}
else {
	return undef;
	}
}

1;

