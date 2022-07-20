#!/usr/local/bin/perl
# never_save.cgi
# Save or delete an never_direct directive

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();

my @never = &find_config("never_direct", $conf);
my $never;
if (defined($in{'index'})) {
	$never = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@never, &indexof($never, @never), 1);
	}
else {
	# update or create
	my @vals = ( $in{'action'} );
	foreach my $y (split(/\0/, $in{'yes'})) { push(@vals, $y); }
	foreach my $n (split(/\0/, $in{'no'})) { push(@vals, "!$n"); }
	my $newnever = { 'name' => 'never_direct', 'values' => \@vals };
	if ($never) { splice(@never, &indexof($never, @never),
			      1, $newnever); }
	else { push(@never, $newnever); }
	}
&save_directive($conf, "never_direct", \@never);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $never ? 'modify' : 'create', 'never');
&redirect("edit_icp.cgi");

