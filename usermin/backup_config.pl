
do 'usermin-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
&get_usermin_miniserv_config(\%miniserv);
local @rv = ( "$config{'usermin_dir'}/config",
	      "$config{'usermin_dir'}/miniserv.conf",
	      "$config{'usermin_dir'}/webmin.cats",
	      "$config{'usermin_dir'}/webmin.catnames",
	      "$config{'usermin_dir'}/usermin.mods",
	      $miniserv{'keyfile'},
	      $miniserv{'certfile'},
	      $miniserv{'ca'},
	      "$config{'usermin_dir'}/webmin.acl",
	      $miniserv{'userfile'},
	      "$config{'usermin_dir'}/user.acl",
	    );
foreach my $m (&list_modules()) {
	push(@rv, "$config{'usermin_dir'}/$m->{'dir'}/config");
	push(@rv, "$config{'usermin_dir'}/$m->{'dir'}/uconfig");
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
# Get current configs, for later merging
&get_usermin_miniserv_config(\%oldminiserv);
&read_file("$config{'usermin_dir'}/config", \%oldconfig);
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
# Merge in local settings that cannot be copied
local %miniserv;
&get_usermin_miniserv_config(\%miniserv);
foreach my $k (keys %oldminiserv) {
	my $copy = 0;
	foreach my $keep ("root", "mimetypes", "logfile", "pidfile",
			  "env_WEBMIN_CONFIG", "env_WEBMIN_VAR", "logout",
			  "passwd_.*") {
		$copy = 1 if ($k =~ /^$keep$/);
		}
	$miniserv{$k} = $oldminiserv{$k} if ($copy);
	}
&put_usermin_miniserv_config(\%miniserv);

local %gconfig;
&read_file("$config{'usermin_dir'}/config", \%gconfig);
foreach my $k (keys %oldconfig) {
	my $copy = 0;
	foreach my $nocopy ("os_type", "os_version",
			    "real_os_type", "real_os_version",
			    "find_pid_command", "ld_env", "passwd_.*") {
		$copy = 1 if ($k =~ /^$keep$/);
		}
	$config{$k} = $oldconfig{$k} if ($copy);
	}
&write_file("$config{'usermin_dir'}/config", \%gconfig);

&flush_modules_cache();
&restart_usermin_miniserv();
return undef;
}

1;

