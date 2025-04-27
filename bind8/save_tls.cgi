#!/usr/local/bin/perl
# Create, update or delete a TLS key and cert

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'tls_ecannot'});
&supports_tls() || &error($text{'tls_esupport'});
&ReadParse();
&error_setup($in{'new'} ? $text{'tls_cerr'} :
	     $in{'delete'} ? $text{'tls_derr'} : $text{'tls_err'});

# Get the TLS config being edited
my $tls;
if (!$in{'new'}) {
	my $conf = &get_config();
	my @tls = &find("tls", $conf);
	($tls) = grep { $_->{'values'}->[0] eq $in{'name'} } @tls;
	$tls || &error($text{'tls_egone'});
	}
else {
	$tls = { 'values' => [],
		 'members' => [] };
	}

if ($in{'delete'}) {
	# Just remove this one TLS key, if unused
	}
else {
	# Validate inputs
	$in{'name'} =~ /^[a-z0-9\-\_]+$/i || &error($text{'tls_ename'});
	}


