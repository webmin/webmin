#!/usr/local/bin/perl
# Save or delete a refresh pattern

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'refresh_err'});

my @refresh = &find_config("refresh_pattern", $conf);
my $h;
if (defined($in{'index'})) {
	$h = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@refresh, &indexof($h, @refresh), 1);
	}
else {
	# update or create
	$in{'re'} =~ /^\S+$/ || &error($text{'refresh_ere'});
	$in{'min'} =~ /^\d+$/ || &error($text{'refresh_emin'});
	$in{'max'} =~ /^\d+$/ || &error($text{'refresh_emax'});
	$in{'pc'} =~ /^\d+$/ && $in{'pc'} >= 0 && $in{'pc'} <= 100 ||
		&error($text{'refresh_epc'});
	my @vals;
	push(@vals, "-i") if ($in{'caseless'});
	push(@vals, $in{'re'}, $in{'min'}, $in{'pc'}.'%', $in{'max'});
	push(@vals, split(/\0/, $in{'options'}));
	my $newr = { 'name' => 'refresh_pattern',
		     'values' => \@vals };
	my $idx = &indexof($h, @refresh);
	if ($h) { splice(@refresh, &indexof($h, @refresh), 1, $newr); }
	else { push(@refresh, $newr); }
	}
&save_directive($conf, "refresh_pattern", \@refresh);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $h ? 'modify' : 'create',
	    "refresh", $in{'re'});
&redirect("list_refresh.cgi");

