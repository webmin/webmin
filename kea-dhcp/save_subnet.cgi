#!/usr/local/bin/perl
# Save a Kea subnet.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
&kea_assert_acl('edit'.$ver);
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);

&error_setup($text{'save_failsave'});
my $sidx = defined($in{'sidx'}) ? $in{'sidx'} : "";
&error($text{'subnet_enone'}) if (!&kea_valid_subnet_parent($root, $sidx));
if ($in{'delete'}) {
	# Delete from whichever parent array currently owns this subnet.
	my $list = &kea_subnet_list($root, $ver, $sidx);
	&error($text{'subnet_enone'}) if ($in{'idx'} !~ /^\d+$/ || !$list->[$in{'idx'}]);
	splice(@$list, $in{'idx'}, 1);
	}
else {
	$in{'id'} =~ /^\d+$/ || &error($text{'subnet_eid'});
	$in{'subnet'} =~ /\S+\/\d+$/ || &error($text{'subnet_esubnet'});

	# A subnet can move between the top-level subnet list and a shared
	# network's nested list, so validate the requested destination before
	# mutating the old one.
	my $target = defined($in{'parent'}) ? $in{'parent'} : "";
	if ($target ne '') {
		&error($text{'shared_enone'})
			if (!&kea_valid_subnet_parent($root, $target));
		}
	my $sub;
	if ($in{'new'}) {
		$sub = { };
		}
	else {
		my $oldlist = &kea_subnet_list($root, $ver, $sidx);
		&error($text{'subnet_enone'}) if ($in{'idx'} !~ /^\d+$/ || !$oldlist->[$in{'idx'}]);
		$sub = $oldlist->[$in{'idx'}];
		splice(@$oldlist, $in{'idx'}, 1) if ($target ne $sidx);
		}
	$sub->{'id'} = int($in{'id'});
	my $canonical = &kea_canonical_subnet($in{'subnet'}, $ver);
	$sub->{'subnet'} = $canonical || $in{'subnet'};
	&kea_set_comment($sub, $in{'desc'});

	# Update scope selectors and address-management children from their
	# row-based form controls.
	&kea_set_optional($sub, 'interface', $in{'interface'});
	&kea_set_relay_addresses($sub, $in{'relay_ip_addresses'});
	$sub->{'pools'} = &kea_parse_pool_rows("pool_");
	$sub->{'pd-pools'} = &kea_parse_pd_pool_rows("pd_") if ($ver == 6);
	delete($sub->{'pd-pools'}) if ($ver != 6);
	$sub->{'reservations'} = &kea_parse_reservation_rows("res_", $ver);

	# Option-data is rebuilt from named common/advanced fields plus
	# free-form rows.
	my $opts = ref($sub->{'option-data'}) eq 'ARRAY' ?
		[ @{$sub->{'option-data'}} ] : [ ];
	&kea_parse_common_option_rows($opts, $ver, "common_");
	&kea_parse_advanced_option_rows($opts, $ver, "adv_");
	$opts = &kea_parse_other_option_rows($opts, $ver, "opt_");
	$sub->{'option-data'} = $opts;
	foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
		       'min-valid-lifetime', 'max-valid-lifetime') {
		&kea_set_optional_integer($sub, $k, $in{$k});
		}
	&kea_set_optional_integer($sub, 'preferred-lifetime',
				  $in{'preferred-lifetime'})
		if ($ver == 6);
	&kea_validate_lifetimes($sub);
	if ($ver == 4) {
		&kea_set_optional_bool($sub, 'authoritative', $in{'authoritative'});
		}
	else {
		delete($sub->{'authoritative'});
		}
	foreach my $k ('next-server', 'server-hostname', 'boot-file-name') {
		&kea_set_optional($sub, $k, $in{$k}) if ($ver == 4);
		}
	if ($in{'new'} || $target ne $sidx) {
		# Append after edits so moved subnets are added to their final
		# parent only once.
		push(@{&kea_subnet_list($root, $ver, $target)}, $sub);
		}
	}

my $saveerr = &kea_save_component_config($c, $data);
&error($saveerr) if ($saveerr);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'subnet', $in{'subnet'}, \%in);
&redirect("index.cgi?mode=dhcp$ver");
