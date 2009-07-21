
do 'shorewall-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
opendir(DIR, $config{'config_dir'});
while($f = readdir(DIR)) {
	next if ($f eq "." || $f eq ".." ||
		 $f =~ /\.rpmsave$/ || $f =~ /\.bak$/);
	push(@rv, "$config{'config_dir'}/$f");
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
local $out = &backquote_logged("$config{'shorewall'} restart 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

1;

