
do 'adsl-client-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
return ( $config{'pppoe_conf'}, $config{'pap_file'} );
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
local ($dev, $ip) = &get_adsl_ip();
if ($ip || $dev) {
	# Stop and re-start connection
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	if ($?) {
		return "<pre>$out</pre>";
		}
	$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
	if ($?) {
		return "<pre>$out</pre>";
		}
	}
return undef;
}

1;

