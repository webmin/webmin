#!/usr/local/bin/perl
# Create, update or delete an extent

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in, %config);
&lock_file($config{'targets_file'});
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($in{'delete'} ? $text{'extent_derr'} : $text{'extent_err'});

my ($extent, $old_extent);
if (!$in{'new'}) {
	# Get the existing extent
	$extent = &find($conf, "extent", $in{'num'});
        $extent || &text('extent_egone', $in{'num'});
	$old_extent = $extent;
	}
else {
	# Creating a new one
	$extent = { 'num' => &find_free_num($conf, 'extent'),
		    'type' => 'extent' };
	}

if ($in{'delete'}) {
	# Check if in use before deleting
	my @users = &find_extent_users($conf, $extent);
	if (@users) {
		&error(&text('extent_einuse',
			join(", ", map { &describe_object($_) } @users)));
		}

	# Delete, after asking for confirmation
	if ($in{'confirm'}) {
		# Delete it
		&save_directive($conf, $extent, undef);
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'extent_edit'}, "");

		print &ui_confirmation_form(
			"save_extent.cgi",
			&text('extent_rusure',
			      &mount::device_name($extent->{'device'})),
			[ [ 'num', $in{'num'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'extent_sure'} ] ],
			);

		&ui_print_footer("list_extents.cgi", $text{'extents_return'});
		return;
		}
	}
else {
	# Validate and store inputs
	if ($in{'mode'} eq 'part') {
		$extent->{'device'} = $in{'part'};
		}
	elsif ($in{'mode'} eq 'raid') {
		$extent->{'device'} = $in{'raid'};
		}
	elsif ($in{'mode'} eq 'lvm') {
		$extent->{'device'} = $in{'lvm'};
		}
	else {
		-f $in{'other'} || &error($text{'extent_eother'});
		$extent->{'device'} = $in{'other'};
		}

	$in{'start'} =~ /^\d+$/ || &error($text{'extent_estart'});
	$extent->{'start'} = $in{'start'}*$in{'start_units'};

	my $maxsize = &get_device_size($extent->{'device'}, $in{'mode'});
	if ($in{'size_def'}) {
		$extent->{'size'} = $maxsize;
		}
	else {
		$in{'size'} =~ /^\d+$/ && $in{'size'} > 0 ||
			&error($text{'extent_esize'});
		$extent->{'size'} = $in{'size'}*$in{'size_units'};
		}
	$extent->{'start'} + $extent->{'size'} <= $maxsize ||
		&error(&text('extent_esizemax', &nice_size($maxsize)));

	# Write out the config
	&save_directive($conf, $old_extent, $extent);
	}

&unlock_file($config{'targets_file'});
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'extent', $extent->{'device'});
&redirect("list_extents.cgi");
