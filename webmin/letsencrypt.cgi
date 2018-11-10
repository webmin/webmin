#!/usr/bin/perl
# Request a new SSL cert using Let's Encrypt

use strict;
use warnings;

require "./webmin-lib.pl";
our %text;
our %miniserv;
our %in;
our $config_directory;
our %config;
our $module_name;
&error_setup($text{'letsencrypt_err'});

# Validate inputs
&ReadParse();
my @doms = split(/\s+/, $in{'dom'});
foreach my $dom (@doms) {
	$dom =~ /^(\*\.)?[a-z0-9\-\.\_]+$/i || &error($text{'letsencrypt_edom'});
	}
$in{'renew_def'} || $in{'renew'} =~ /^[1-9][0-9]*$/ ||
	&error($text{'letsencrypt_erenew'});
$in{'size_def'} || $in{'size'} =~ /^\d+$/ ||
	&error($text{'newkey_esize'});
my $size = $in{'size_def'} ? undef : $in{'size'};
my $webroot;
my $mode = "web";
if ($in{'webroot_mode'} == 3) {
	# Validation via DNS
	$mode = "dns";
	}
elsif ($in{'webroot_mode'} == 2) {
	# Some directory
	$in{'webroot'} =~ /^\/\S+/ && -d $in{'webroot'} ||
		&error($text{'letsencrypt_ewebroot'});
	$webroot = $in{'webroot'};
	}
else {
	# Apache domain
	&foreign_require("apache");
	my $conf = &apache::get_config();
	foreach my $virt (&apache::find_directive_struct(
				"VirtualHost", $conf)) {
		my $sn = &apache::find_directive(
			"ServerName", $virt->{'members'});
		my $match = 0;
		if ($in{'webroot_mode'} == 0 && $sn eq $doms[0]) {
			# Based on domain name
			$match = 1;
			}
		elsif ($in{'webroot_mode'} == 1 && $sn eq $in{'vhost'}) {
			# Specifically selected domain
			$match = 1;
			}
		if ($match) {
			# Get document root
			$webroot = &apache::find_directive(
				"DocumentRoot", $virt->{'members'}, 1);
			$webroot || &error(&text('letsencrypt_edroot', $sn));
			last;
			}
		}
	$webroot || &error(&text('letsencrypt_evhost', $doms[0]));
	}

if ($in{'save'}) {
	# Just update renewal
	&save_renewal_only(\@doms, $webroot, $mode);
	&redirect("edit_ssl.cgi");
	}
else {
	# Request the cert
	&ui_print_unbuffered_header(undef, $text{'letsencrypt_title'}, "");

	print &text($mode eq 'dns' ? 'letsencrypt_doingdns'
				   : 'letsencrypt_doing',
		    "<tt>".&html_escape(join(", ", @doms))."</tt>",
		    "<tt>".&html_escape($webroot)."</tt>"),"<p>\n";
	my ($ok, $cert, $key, $chain) = &request_letsencrypt_cert(\@doms, $webroot, undef, $size, $mode, $in{'staging'});
	if (!$ok) {
		print &text('letsencrypt_failed', $cert),"<p>\n";
		}
	else {
		# Worked, now copy to Webmin
		print $text{'letsencrypt_done'},"<p>\n";

		if ($in{'use'}) {
			# Copy cert, key and chain to Webmin
			print $text{'letsencrypt_webmin'},"<p>\n";
			&lock_file($ENV{'MINISERV_CONFIG'});
			&get_miniserv_config(\%miniserv);

			$miniserv{'keyfile'} = $config_directory.
					       "/letsencrypt-key.pem";
			&lock_file($miniserv{'keyfile'});
			&copy_source_dest($key, $miniserv{'keyfile'}, 1);
			&unlock_file($miniserv{'keyfile'});

			$miniserv{'certfile'} = $config_directory.
						"/letsencrypt-cert.pem";
			&lock_file($miniserv{'certfile'});
			&copy_source_dest($cert, $miniserv{'certfile'}, 1);
			&unlock_file($miniserv{'certfile'});

			if ($chain) {
				$miniserv{'extracas'} = $config_directory.
							"/letsencrypt-ca.pem";
				&lock_file($miniserv{'extracas'});
				&copy_source_dest($chain, $miniserv{'extracas'}, 1);
				&unlock_file($miniserv{'extracas'});
				}
			else {
				delete($miniserv{'extracas'});
				}
			&put_miniserv_config(\%miniserv);
			&unlock_file($ENV{'MINISERV_CONFIG'});

			&save_renewal_only(\@doms, $webroot, $mode);

			&webmin_log("letsencrypt");
			&restart_miniserv(1);
			print $text{'letsencrypt_wdone'},"<p>\n";
			}
		else {
			# Just tell the user
			print $text{'letsencrypt_show'},"<p>\n";
			my @grid = ( $text{'letsencrypt_cert'}, $cert,
				     $text{'letsencrypt_key'}, $key );
			if ($chain) {
				push(@grid, $text{'letsencrypt_chain'}, $chain);
				}
			print &ui_grid_table(\@grid, 2);
			}
		}

	&ui_print_footer("", $text{'index_return'});
	}

# save_renewal_only(&doms, webroot, mode)
# Save for future renewals
sub save_renewal_only
{
my ($doms, $webroot, $mode) = @_;
$config{'letsencrypt_doms'} = join(" ", @$doms);
$config{'letsencrypt_webroot'} = $webroot;
$config{'letsencrypt_mode'} = $mode;
$config{'letsencrypt_size'} = $size;
&save_module_config();
if (&foreign_check("webmincron")) {
	my $job = &find_letsencrypt_cron_job();
	if ($in{'renew_def'}) {
		&webmincron::delete_webmin_cron($job) if ($job);
		}
	else {
		my @tm = localtime(time() - 60);
		$job ||= { 'module' => $module_name,
			   'func' => 'renew_letsencrypt_cert' };
		$job->{'mins'} ||= $tm[1];
		$job->{'hours'} ||= $tm[2];
		$job->{'days'} ||= $tm[3];
		$job->{'months'} = '*/'.$in{'renew'};
		$job->{'weekdays'} = '*';
		&webmincron::create_webmin_cron($job);
		}
	}
}
