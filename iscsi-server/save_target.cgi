#!/usr/local/bin/perl
# Create, update or delete an target

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in, %config);
&lock_file($config{'targets_file'});
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($in{'delete'} ? $text{'target_derr'} : $text{'target_err'});

my ($target, $old_target);
if (!$in{'new'}) {
	# Get the existing target
	$target = &find($conf, "target", $in{'num'});
        $target || &text('target_egone', $in{'num'});
	$old_target = $target;
	}
else {
	# Creating a new one
	$target = { 'num' => &find_free_num($conf, 'target'),
		    'type' => 'target' };
	}

if ($in{'delete'}) {
	# Delete, after asking for confirmation
	if ($in{'confirm'}) {
		# Delete it
		&save_directive($conf, $target, undef);
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'target_edit'}, "");

		print &ui_confirmation_form(
			"save_target.cgi",
			&text('target_rusure', $target->{'network'}),
			[ [ 'num', $in{'num'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'target_sure'} ] ],
			);

		&ui_print_footer("list_targets.cgi", $text{'targets_return'});
		return;
		}
	}
else {
	# Validate and store inputs
	$target->{'export'} = $in{'export'};
	$target->{'flags'} = $in{'flags'};
	if ($in{'network_def'}) {
		$target->{'network'} = '0/0';
		}
	else {
		&check_ipaddress($in{'network'}) ||
		    &check_ip6address($in{'network'}) ||
			&error($text{'target_enetwork'});
		$in{'mask'} =~ /^\d+$/ && $in{'mask'} >= 0 &&
		    $in{'mask'} <= 32 || &error($text{'target_emask'});
		$target->{'network'} = $in{'network'}."/".$in{'mask'};
		}

	# Write out the config
	&save_directive($conf, $old_target, $target);
	}

&unlock_file($config{'targets_file'});
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'target', $target->{'network'});
&redirect("list_targets.cgi");
