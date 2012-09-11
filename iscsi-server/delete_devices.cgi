#!/usr/local/bin/perl
# Delete multiple devices

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in, %config);
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($text{'devices_derr'});

# Get the devices
my @devices;
my @d = split(/\0/, $in{'d'});
foreach my $d (@d) {
	push(@devices, grep { $_->{'type'} eq 'device' &&
			      $_->{'num'} eq $d } @$conf);
	}
@devices || &error($text{'devices_denone'});

# Check if in use
foreach my $device (@devices) {
	my @users = &find_extent_users($conf, $device);
	if (@users) {
		&error(&text('devices_einuse',
			$device->{'type'}.$device->{'num'},
			join(", ", map { &describe_object($_) } @users)));
		}
	}

if ($in{'confirm'}) {
	# Do the deletion
	&lock_file($config{'targets_file'});

	foreach my $device (@devices) {
		&save_directive($conf, $device, undef);
		}

	&unlock_file($config{'targets_file'});
	if (@devices == 1) {
		&webmin_log('delete', 'device', $devices[0]->{'type'}.
						$devices[0]->{'num'});
		}
	else {
		&webmin_log('delete', 'devices', scalar(@devices));
		}
	&redirect("list_devices.cgi");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'devices_title'}, "");

	print &ui_confirmation_form(
		"delete_devices.cgi",
		&text('devices_drusure',
		      join(" ", map { $_->{'type'}.$_->{'num'} } @devices)),
		[ map { [ "d", $_ ] } @d ],
		[ [ 'confirm', $text{'devices_sure'} ] ],
		);

	&ui_print_footer("list_devices.cgi", $text{'devices_return'});
	}

