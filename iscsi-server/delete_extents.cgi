#!/usr/local/bin/perl
# Delete multiple extents

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text, %in, %config);
my $conf = &get_iscsi_config();
&ReadParse();
&error_setup($text{'extents_derr'});

# Get the extents
my @extents;
my @d = split(/\0/, $in{'d'});
foreach my $d (@d) {
	push(@extents, grep { $_->{'type'} eq 'extent' &&
			      $_->{'num'} eq $d } @$conf);
	}
@extents || &error($text{'extents_denone'});

# Check if in use
foreach my $extent (@extents) {
	my @users = &find_extent_users($conf, $extent);
	if (@users) {
		&error(&text('extents_einuse',
			&mount::device_name($extent->{'device'}),
			join(", ", map { &describe_object($_) } @users)));
		}
	}

if ($in{'confirm'}) {
	# Do the deletion
	&lock_file($config{'targets_file'});

	foreach my $extent (@extents) {
		&save_directive($conf, $extent, undef);
		}

	&unlock_file($config{'targets_file'});
	if (@extents == 1) {
		&webmin_log('delete', 'extent', $extents[0]->{'device'});
		}
	else {
		&webmin_log('delete', 'extents', scalar(@extents));
		}
	&redirect("list_extents.cgi");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'extents_title'}, "");

	print &ui_confirmation_form(
		"delete_extents.cgi",
		&text('extents_drusure',
		      join(" ", map { &mount::device_name($_->{'device'}) }
				    @extents)),
		[ map { [ "d", $_ ] } @d ],
		[ [ 'confirm', $text{'extents_sure'} ] ],
		);

	&ui_print_footer("list_extents.cgi", $text{'extents_return'});
	}

