#!/usr/local/bin/perl
# find.cgi
# Broadcast to other webmin servers

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%text, %access, %in, %config);
&ReadParse();
$access{'find'} || &error($text{'find_ecannot'});

my $limit;
my @broad;
if (defined($in{'scan'})) {
	# send to all addresses on the given network
	$in{'scan'} =~ /^(\d+\.\d+\.\d+)\.0$/ || &error($text{'find_escan'});
	for(my $i=0; $i<256; $i++) {
		push(@broad, "$1.$i");
		}
	$limit = $config{'scan_time'};
	$in{'port'} =~ /^\d+$/ || &error($text{'find_eport'});
	}
else {
	# broadcast to some useful addresses
	my $myip = &get_my_address();
	if ($myip) {
		push(@broad, &address_to_broadcast($myip, 0));
		}
	push(@broad, "255.255.255.255");
	$limit = 2;
	}

# Add local network addresses
if (&foreign_check("net") && !defined($in{'scan'})) {
	&foreign_require("net", "net-lib.pl");
	foreach my $a (&foreign_call("net", "active_interfaces")) {
		push(@broad, $a->{'broadcast'}) if ($a->{'broadcast'});
		}
	}

# Get and display responses
&ui_print_unbuffered_header(undef, $text{'find_title'}, "");
if (defined($in{'scan'})) {
	print &text('find_scanning', "<tt>".&html_escape($in{'scan'})."</tt>"),"<p>\n";
	}
else {
	print &text('find_broading', join(" , ", map { "<tt>".&html_escape($_)."</tt>" } @broad)),"<p>\n";
	}
&find_servers(\@broad, $limit, 0, $in{'defuser'}, $in{'defpass'}, undef, undef,
	      0, $in{'port'});

&ui_print_footer("", $text{'index_return'});

