
require 'webmin-lib.pl';

sub module_install
{
# Update cache of which module's underlying servers are installed 
&build_installed_modules();

# Pick a random update time
if (!defined($config{'uphour'}) ||
    $config{'uphour'} == 3 && $config{'upmins'} == 0 && !$config{'update'}) {
	&seed_random();
	$config{'uphour'} = int(rand()*24);
	$config{'upmins'} = int(rand()*60);
	&save_module_config();
	}

# Figure out the preferred cipher mode
&lock_file("$config_directory/miniserv.conf");
my %miniserv;
&get_miniserv_config(\%miniserv);
if (!defined($miniserv{'cipher_list_def'})) {
	# No mode set, so guess based on ciphers
	my $clist = $miniserv{'ssl_cipher_list'};
	my $cmode = !$clist ? 1 :
		    $clist eq $strong_ssl_ciphers ? 2 :
		    $clist eq $pfs_ssl_ciphers ? 3 :
		    0;
	$miniserv{'cipher_list_def'} = $cmode;
	}
elsif ($miniserv{'cipher_list_def'} == 2 || $miniserv{'cipher_list_def'} == 3) {
	# Sync ciphers with Webmin's preferred list
	$miniserv{'ssl_cipher_list'} = $miniserv{'cipher_list_def'} == 2 ?
		$strong_ssl_ciphers : $pfs_ssl_ciphers;
	}

# If this is the first install, enable recording of logins by default
if (!-r $first_install_file || $miniserv{'login_script'} eq $record_login_cmd) {
	&foreign_require("cron");
	&cron::create_wrapper($record_login_cmd, "", "record-login.pl");
	&cron::create_wrapper($record_logout_cmd, "", "record-logout.pl");
	&cron::create_wrapper($record_failed_cmd, "", "record-failed.pl");
	$miniserv{'login_script'} = $record_login_cmd;
	$miniserv{'logout_script'} = $record_logout_cmd;
	$miniserv{'failed_script'} = $record_failed_cmd;
	}

&put_miniserv_config(\%miniserv);
&unlock_file("$config_directory/miniserv.conf");

# Record the version of Webmin at first install
if (!-r $first_install_file) {
	my %first;
	$first{'version'} = &get_webmin_version();
	&write_file($first_install_file, \%first);
	}
}

