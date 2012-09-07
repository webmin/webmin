#!/usr/local/bin/perl
# Delete multiple targets

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in, %config);
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($text{'targets_derr'});

# Get the targets
my @targets;
my @d = split(/\0/, $in{'d'});
foreach my $d (@d) {
	push(@targets, grep { $_->{'type'} eq 'target' &&
			      $_->{'num'} eq $d } @$conf);
	}
@targets || &error($text{'targets_denone'});

if ($in{'confirm'}) {
	# Do the deletion
	&lock_file($config{'targets_file'});

	foreach my $target (@targets) {
		&save_directive($conf, $target, undef);
		}

	&unlock_file($config{'targets_file'});
	if (@targets == 1) {
		&webmin_log('delete', 'target', $targets[0]->{'network'});
		}
	else {
		&webmin_log('delete', 'targets', scalar(@targets));
		}
	&redirect("list_targets.cgi");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'targets_title'}, "");

	print &ui_confirmation_form(
		"delete_targets.cgi",
		&text('targets_drusure',
		      join(" ", map { $_->{'network'} } @targets)),
		[ map { [ "d", $_ ] } @d ],
		[ [ 'confirm', $text{'targets_sure'} ] ],
		);

	&ui_print_footer("list_targets.cgi", $text{'targets_return'});
	}

