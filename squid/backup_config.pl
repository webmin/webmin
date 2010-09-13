
do 'squid-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
# Add main config file
local @rv = ( $config{'squid_conf'} );

# Add users file
local $conf = &get_config();
local $file = &get_auth_file($conf);
push(@rv, $file) if ($file);

# Add files from ACLs
local @acl = &find_config("acl", $conf);
local $a;
foreach $a (@acl) {
	if ($a->{'values'}->[2] =~ /^"(.*)"$/ || $a->{'values'}->[3] =~ /^"(.*)"$/) {
		push(@rv, $1);
		}
	}

return &unique(@rv);
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
return &apply_configuration();
}

1;

