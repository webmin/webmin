#!/usr/local/bin/perl
# Save a Kea shared network.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pedit'.$ver}")
	if (!$access{'edit'.$ver});
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);
my $shareds = &kea_shared_networks($root);

&error_setup($text{'save_failsave'});
if ($in{'delete'}) {
	# Shared networks cannot be deleted while they still own subnets,
	# because Kea stores those subnets inside the shared-network object.
	&error($text{'shared_enone'}) if ($in{'idx'} !~ /^\d+$/ || !$shareds->[$in{'idx'}]);
	my $subs = &kea_subnet_list($root, $ver, $in{'idx'});
	&error($text{'shared_enonempty'}) if (@$subs);
	splice(@$shareds, $in{'idx'}, 1);
	}
else {
	$in{'name'} =~ /\S/ || &error($text{'shared_ename'});

	# Create or locate the shared network object, then update only the
	# fields owned by the structured editor.
	my $shared;
	if ($in{'new'}) {
		$shared = { };
		push(@$shareds, $shared);
		}
	else {
		&error($text{'shared_enone'}) if ($in{'idx'} !~ /^\d+$/ || !$shareds->[$in{'idx'}]);
		$shared = $shareds->[$in{'idx'}];
		}
	$shared->{'name'} = $in{'name'};
	&kea_set_comment($shared, $in{'desc'});
	&kea_set_optional($shared, 'interface', $in{'interface'});
	&kea_set_relay_addresses($shared, $in{'relay_ip_addresses'});

	# Merge named option fields and free-form option-data rows without
	# discarding unmanaged option properties.
	my $opts = ref($shared->{'option-data'}) eq 'ARRAY' ?
		[ @{$shared->{'option-data'}} ] : [ ];
	&kea_parse_common_option_rows($opts, $ver, "common_");
	&kea_parse_advanced_option_rows($opts, $ver, "adv_");
	$opts = &kea_parse_other_option_rows($opts, $ver, "opt_");
	$shared->{'option-data'} = $opts;
	foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
		       'min-valid-lifetime', 'max-valid-lifetime') {
		&kea_set_optional_integer($shared, $k, $in{$k});
		}
	&kea_set_optional_integer($shared, 'preferred-lifetime',
				  $in{'preferred-lifetime'})
		if ($ver == 6);
	&kea_validate_lifetimes($shared);
	if ($ver == 4) {
		&kea_set_optional_bool($shared, 'authoritative', $in{'authoritative'});
		}
	else {
		delete($shared->{'authoritative'});
		}
	}

my $saveerr = &kea_save_component_config($c, $data);
&error($saveerr) if ($saveerr);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'shared-network', $in{'name'}, \%in);
&redirect("index.cgi?mode=dhcp$ver");
