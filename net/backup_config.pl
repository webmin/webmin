
do 'net-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'hosts_file'} );
if ($config{'ipnodes_file'}) {
	push(@rv, $config{'ipnodes_file'});
	}
local $dns = &get_dns_config();
push(@rv, @{$dns->{'files'}});
if (defined(&routing_config_files)) {
	push(@rv, &routing_config_files());
	}
if (defined(&network_config_files)) {
	push(@rv, &network_config_files());
	}
push(@rv, map { $_->{'file'} } &boot_interfaces());
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
if (defined(&apply_network)) {
	&apply_network();
	}
return undef;
}

1;

