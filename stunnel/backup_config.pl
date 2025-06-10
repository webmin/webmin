
do 'stunnel-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @tunnels = &list_stunnels();
local @rv = map { $_->{'file'} } @tunnels;
local $t;
local $ver = &get_stunnel_version();
foreach $t (@tunnels) {
	if ($ver >= 4) {
		if ($t->{'args'} =~ /^(\S+)\s+(\S+)/) {
			local $cfile = $2;
			local @conf = &get_stunnel_config($cfile);
			push(@rv, $cfile);
			local ($conf) = grep { !$_->{'name'} } @conf;
			if ($conf->{'values'}->{'cert'}) {
				push(@rv, $conf->{'values'}->{'cert'});
				}
			}
		}
	else {
		if ($t->{'args'} =~ /\s*-p\s+(\S+)/) {
			push(@rv, $1);
			}
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

