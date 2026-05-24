#!/usr/local/bin/perl
# Delete selected Kea DHCP subnets and shared networks.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
&kea_assert_acl('edit'.$ver);
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);

&error_setup($text{'delete_failsave'});
my @shared = split(/\0/, defined($in{'d_shared'}) ? $in{'d_shared'} : "");
my @subnets = split(/\0/, defined($in{'d_subnet'}) ? $in{'d_subnet'} : "");
@shared || @subnets || &error($text{'delete_enone'});

# Group subnet deletions by parent so indexes can be removed descending within
# each array without disturbing later deletions.
my %subnets_by_parent;
foreach my $v (@subnets) {
	$v =~ /^(\d*):(\d+)$/ || &error($text{'subnet_enone'});
	my ($sidx, $idx) = ($1, $2);
	&error($text{'subnet_enone'})
		if (!&kea_valid_subnet_parent($root, $sidx));
	my $list = &kea_subnet_list($root, $ver, $sidx);
	&error($text{'subnet_enone'}) if (!$list->[$idx]);
	push(@{$subnets_by_parent{$sidx}}, $idx);
	}
foreach my $sidx (keys %subnets_by_parent) {
	my $list = &kea_subnet_list($root, $ver, $sidx);
	foreach my $idx (sort { $b <=> $a } @{$subnets_by_parent{$sidx}}) {
		splice(@$list, $idx, 1);
		}
	}

# Shared networks are top-level siblings, so delete them after nested subnets.
my $shareds = &kea_shared_networks($root);
foreach my $idx (sort { $b <=> $a } @shared) {
	$idx =~ /^\d+$/ || &error($text{'shared_enone'});
	&error($text{'shared_enone'}) if (!$shareds->[$idx]);
	my $subs = &kea_subnet_list($root, $ver, $idx);
	&error($text{'shared_enonempty'}) if (@$subs);
	splice(@$shareds, $idx, 1);
	}

my $saveerr = &kea_save_component_config($c, $data);
&error($saveerr) if ($saveerr);
&webmin_log("delete", "objects", scalar(@shared) + scalar(@subnets), \%in);
&redirect("index.cgi?mode=dhcp$ver");
