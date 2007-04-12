
do 'apache-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;

# Add main config files
local $conf = &get_config();
push(@rv, map { $_->{'file'} } @$conf);

# Add mime types file
local $mfile = &find_directive("TypesConfig", $conf);
if (!$mfile) { $mfile = $config{'mime_types'}; }
if (!$mfile) { $mfile = &server_root("etc/mime.types", $conf); }
if (!-r $mfile) { $mfile = &server_root("conf/mime.types", $conf); }
if ($mfile) {
	push(@rv, &server_root($mfile, $conf));
	}

# Add mime magic file
local $magic = &find_directive("MimeMagicFile", $conf);
if ($magic) {
	push(@rv, &server_root($magic, $conf));
	}

# Add all auth files
local $auth;
foreach $auth (&find_all_directives($conf, "AuthUserFile"),
	       &find_all_directives($conf, "AuthGroupFile")) {
	push(@rv, &server_root($auth, $conf));
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
local $pidfile = &get_pid_file();
if (&check_pid_file($pidfile)) {
	return &restart_apache();
	}
return undef;
}

1;

