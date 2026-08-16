
do 'logrotate-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
# Keep backup behavior unchanged on systems without the vendor overlay.
if (!$config{'vendor_logrotate_conf'} && !$config{'vendor_add_file'}) {
	local $conf = &get_config();
	return &unique(map { $_->{'file'} } @$conf);
	}

# Back up only writable files.  Use the complete effective file list so an
# empty local file that intentionally shadows a vendor file is preserved.
local ($conf, $lnum, $files) = &get_config();
return &unique(grep { !&is_vendor_main_config($_) &&
		      !&is_vendor_config_file($_) }
	       @$files);
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

