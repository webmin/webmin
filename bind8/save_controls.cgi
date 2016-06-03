#!/usr/local/bin/perl
# Save control interface options
use strict;
use warnings;
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'controls_ecannot'});
&error_setup($text{'controls_err'});
&ReadParse();

# Validate and store inputs
&lock_file(&make_chroot($config{'named_conf'}));
my $parent = &get_config_parent();
my $conf = &get_config();
my $controls = &find("controls", $conf);
if (!$controls) {
	$controls = { 'name' => 'controls', 'type' => 1 };
	&save_directive($parent, "controls", [ $controls ]);
	}
my $inet = &find("inet", $controls->{'members'});
my $unix = &find("unix", $controls->{'members'});

# Save inet control options
if ($in{'inet'}) {
	$inet ||= { 'name' => 'inet', 'type' => 2 };
	&check_ipaddress($in{'ip'}) || &error($text{'controls_einetip'});
	$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
		&error($text{'controls_einetport'});
	$inet->{'values'} = [ $in{'ip'}, "port", $in{'port'} ];
	my @allow = split(/\s+/, $in{'allow'});
	foreach my $a (@allow) {
		&check_ipaddress($a) ||
			&error(&text('controls_einetallow', $a));
		}
	@allow || &error($text{'controls_einetallows'});
	$inet->{'members'}->{'allow'} =
		[ map { { 'name' => $_ } } @allow ];
	my @keys = split(/\s+/, $in{'keys'});
	if (@keys) {
		$inet->{'members'}->{'keys'} = 
			[ map { { 'name' => $_ } } @keys ];
		}
	else {
		delete($inet->{'members'}->{'keys'});
		}
	&save_directive($controls, "inet", [ $inet ], 1);
	}
else {
	&save_directive($controls, "inet", [ ], 1);
	}

# Save local control options
if ($in{'unix'}) {
	$unix ||= { 'name' => 'unix', 'type' => 0 };
	$in{'path'} =~ /^\/\S+$/ || &error($text{'controls_eunixpath'});
	$in{'perm'} =~ /^[0-7]{3,4}$/ || &error($text{'controls_eunixperm'});
	my $owner = getpwnam($in{'owner'});
	defined($owner) || &error($text{'controls_eunixowner'});
	my $group = getgrnam($in{'group'});
	defined($group) || &error($text{'controls_eunixgroup'});
	$unix->{'values'} = [ $in{'path'}, "perm", $in{'perm'},
			      "owner", $owner, "group", $group ];
	&save_directive($controls, "unix", [ $unix ], 1);
	}
else {
	&save_directive($controls, "unix", [ ], 1);
	}

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("controls", undef, undef, \%in);
&redirect("");

