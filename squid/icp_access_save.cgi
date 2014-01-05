#!/usr/local/bin/perl
# icp_access_save.cgi
# Save or delete a proxy restriction

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'saicp_ftsir'});

my @icps = &find_config("icp_access", $conf);
my ($icp, %used);
if (defined($in{'index'})) {
	$icp = $conf->[$in{'index'}];
	}
if ($in{'delete'}) {
	# delete this restriction
	splice(@icps, &indexof($icp, @icps), 1);
	}
else {
	# update or create
	my @vals = ( $in{'action'} );
	foreach my $y (split(/\0/, $in{'yes'})) {
		push(@vals, $y);
		$used{$y}++;
		}
	foreach my $n (split(/\0/, $in{'no'})) {
		push(@vals, "!$n");
		$used{$n}++;
		}
	my $newicp = { 'name' => 'icp_access', 'values' => \@vals };
	if ($icp) { splice(@icps, &indexof($icp, @icps), 1, $newicp); }
	else { push(@icps, $newicp); }
	}

# Find the last referenced ACL
my @acls = grep { $used{$_->{'values'}->[0]} } &find_config("acl", $conf);
my $lastacl = @acls ? $acls[$#acls] : undef;

&save_directive($conf, "icp_access", \@icps, $lastacl);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $icp ? 'modify' : 'create', "icp");
&redirect("edit_acl.cgi?mode=icp");

