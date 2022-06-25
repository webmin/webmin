
do 'webmin-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
&get_miniserv_config(\%miniserv);
my @rv = ( "$config_directory/config",
	      "$config_directory/miniserv.conf",
	      "$config_directory/webmin.cats",
	      "$config_directory/webmin.catnames",
	      "$config_directory/webmin.desc",
	      $miniserv{'keyfile'},
	      $miniserv{'certfile'},
	      $miniserv{'ca'},
	      $newmodule_users_file,
	      "$config_directory/custom-lang",
	      glob("$config_directory/*/custom-lang"),
	    );
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
&get_miniserv_config(\%oldminiserv);
&read_file("$config_directory/config", \%oldconfig);
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
# Merge in local settings that cannot be copied
my %miniserv;
&get_miniserv_config(\%miniserv);
foreach my $k (keys %oldminiserv) {
	my $copy = 0;
	foreach my $keep ("root", "mimetypes", "logfile", "pidfile",
			  "env_WEBMIN_CONFIG", "env_WEBMIN_VAR", "logout",
			  "userfile", "passwd_.*") {
		$copy = 1 if ($k =~ /^$keep$/);
		}
	$miniserv{$k} = $oldminiserv{$k} if ($copy);
	}
&put_miniserv_config(\%miniserv);

my %gconfig;
&read_file("$config_directory/config", \%gconfig);
foreach my $k (keys %oldconfig) {
	my $copy = 0;
	foreach my $nocopy ("os_type", "os_version",
			    "real_os_type", "real_os_version",
			    "find_pid_command", "ld_env", "passwd_.*") {
		$copy = 1 if ($k =~ /^$keep$/);
		}
	$config{$k} = $oldconfig{$k} if ($copy);
	}
&write_file("$config_directory/config", \%gconfig);

unlink("$config_directory/module.infos.cache");
&restart_miniserv();
return undef;
}

1;

