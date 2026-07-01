
require 'webmin-lib.pl';

sub module_install
{
# Update cache of which module's underlying servers are installed 
&build_installed_modules();

# Remove the scheduled module update cron, which is now obsolete
&foreign_require("cron");
my @jobs = &cron::list_cron_jobs();
my $job = &find_cron_job(\@jobs);
if ($job) {
	&cron::delete_cron_job($job);
	&unlink_logged($cron_cmd);
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

# Convert old Let's Encrypt renewal schedules to elapsed interval timers
if (&foreign_check("webmincron")) {
	my $job = &find_letsencrypt_cron_job();
	if ($job && !$job->{'interval'} &&
	    $job->{'months'} =~ /^\*\/([1-9][0-9]*)$/) {
		my $renew = $1;
		$job->{'mins'} = '';
		$job->{'hours'} = '';
		$job->{'days'} = '';
		$job->{'weekdays'} = '';
		$job->{'interval'} = $renew*30*24*60*60;
		&webmincron::save_webmin_cron($job);
		}
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

# Disable trusting SSL certs unless already enabled. Legacy configs with
# trust_real_ip but no trusted proxy cannot safely authenticate from
# proxied SSL client cert headers.
my @trusted_proxies = split(/\s+/, $miniserv{'trusted_proxies'} || "");
if ((!$miniserv{'trust_real_ip'} || !@trusted_proxies) &&
    !defined($miniserv{'no_trust_ssl'})) {
	$miniserv{'no_trust_ssl'} = 1;
	}

&put_miniserv_config(\%miniserv);
&unlock_file("$config_directory/miniserv.conf");

# Create a link from /usr/sbin/webmin to bin/webmin under the root dir
my $bindir = "/usr/sbin";
my $lnk = $bindir."/webmin";
if (-d $bindir && !-e $lnk) {
	&symlink_file($lnk, $root_directory."/bin/webmin");
	}

# Record the version of Webmin at first install
if (!-r $first_install_file) {
	my %first;
	$first{'version'} = &get_webmin_version();
	&write_file($first_install_file, \%first);
	}
}

