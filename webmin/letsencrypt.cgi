#!/usr/bin/perl
# Request a new SSL cert using Let's Encrypt

use strict;
use warnings;

require "./webmin-lib.pl";
our %text;
our %miniserv;
our %in;
&error_setup($text{'letsencrypt_err'});

# Validate inputs
&ReadParse();
$in{'dom'} =~ /^[a-z0-9\-\.\_]+$/i || &error($text{'letsencrypt_edom'});
my $webroot;
if ($in{'webroot_mode'} == 2) {
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
		if ($in{'webroot_mode'} == 0 && $sn eq $in{'dom'}) {
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
				"DocumentRoot", $virt->{'members'});
			$webroot || &error(&text('letsencrypt_edroot', $sn));
			last;
			}
		}
	$webroot || &error(&text('letsencrypt_evhost', $in{'dom'}));
	}

# Request the cert
&ui_print_unbuffered_header(undef, $text{'letsencrypt_title'}, "");

print &text('letsencrypt_doing',
	    "<tt>".&html_escape($in{'dom'})."</tt>",
	    "<tt>".&html_escape($webroot)."</tt>"),"<p>\n";
my ($ok, $cert, $key, $chain) = &request_letsencrypt_cert($in{'dom'}, $webroot);
if (!$ok) {
	print &text('letsencrypt_failed',
		    "<pre>".&html_escape($cert)."</pre>"),"<p>\n";
	}
else {
	# Worked, now copy to Webmin
	print $text{'letsencrypt_done'},"<p>\n";

	if ($in{'use'}) {
		# Copy cert, key and chain to Webmin
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
