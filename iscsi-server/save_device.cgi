#!/usr/local/bin/perl
# Create, update or delete an device

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text, %in, %config);
&lock_file($config{'targets_file'});
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($in{'delete'} ? $text{'device_derr'} : $text{'device_err'});

my ($device, $old_device);
if (!$in{'new'}) {
	# Get the existing device
	$device = &find($conf, "device", $in{'num'});
        $device || &text('device_egone', $in{'num'});
	$old_device = $device;
	}
else {
	# Creating a new one
	$device = { 'num' => &find_free_num($conf, 'device'),
		    'type' => 'device' };
	}

if ($in{'delete'}) {
	# Check if in use before deleting
	my @users = &find_extent_users($conf, $device);
	if (@users) {
		&error(&text('device_einuse',
			join(", ", map { &describe_object($_) } @users)));
		}

	# Delete, after asking for confirmation
	if ($in{'confirm'}) {
		# Delete it
		&save_directive($conf, $device, undef);
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'device_edit'}, "");

		print &ui_confirmation_form(
			"save_device.cgi",
			&text('device_rusure', $device->{'type'}.$device->{'num'}),
			[ [ 'num', $in{'num'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'device_sure'} ] ],
			);

		&ui_print_footer("list_devices.cgi", $text{'devices_return'});
		return;
		}
	}
else {
	# Validate and store inputs
	$device->{'mode'} = $in{'mode'};
	my @extents = split(/\r?\n/, $in{'extents'});
	@extents || &error($text{'device_eextents'});
	$device->{'extents'} = \@extents;
	if (&indexof($device->{'type'}.$device->{'num'},
		     &expand_extents($conf, { }, @extents)) >= 0) {
		# Contains self!?
		&error($text{'device_eself'});
		}

	# Write out the config
	&save_directive($conf, $old_device, $device);
	}

&unlock_file($config{'targets_file'});
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'device', $device->{'type'}.$device->{'num'});
&redirect("list_devices.cgi");
