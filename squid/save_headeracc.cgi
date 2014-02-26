#!/usr/local/bin/perl
# Save or delete an HTTP header access control rule

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'headeracc'} || &error($text{'headeracc_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'headeracc_err'});

my @headeracc = &find_config($in{'type'}, $conf);
my $h;
if (defined($in{'index'})) {
	$h = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@headeracc, &indexof($h, @headeracc), 1);
	}
else {
	# update or create
	$in{'name'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'header_ename'});
	my @vals = ( $in{'name'}, $in{'action'} );
	foreach my $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach my $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	my $newh = { 'name' => $in{'type'}, 'values' => \@vals };
	if ($h) { splice(@headeracc, &indexof($h, @headeracc), 1, $newh); }
	else { push(@headeracc, $newh); }
	}
&save_directive($conf, $in{'type'}, \@headeracc);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $h ? 'modify' : 'create',
	    "headeracc", $in{'name'});
&redirect("list_headeracc.cgi");

