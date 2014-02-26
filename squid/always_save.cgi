#!/usr/local/bin/perl
# always_save.cgi
# Save or delete an always_direct directive

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();

my @always = &find_config("always_direct", $conf);
my $always;
if (defined($in{'index'})) {
	$always = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@always, &indexof($always, @always), 1);
	}
else {
	# update or create
	my @vals = ( $in{'action'} );
	foreach my $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach my $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	my $newalways = { 'name' => 'always_direct', 'values' => \@vals };
	if ($always) { splice(@always, &indexof($always, @always),
			      1, $newalways); }
	else { push(@always, $newalways); }
	}
&save_directive($conf, "always_direct", \@always);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $always ? 'modify' : 'create', 'always');
&redirect("edit_icp.cgi");

