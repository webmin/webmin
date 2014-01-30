#!/usr/local/bin/perl
# Delete serveral servers at once

use strict;
use warnings;
require './servers-lib.pl';
our (%text, %access, %in);
&ReadParse();
&error_setup($text{'delete_err'});

# Validate inputs
my @del = split(/\0/, $in{'d'});
@del || &error($text{'delete_enone'});
$access{'edit'} || &error($text{'delete_ecannot'});

if ($in{'confirm'}) {
	# Go ahead and delete
	foreach my $d (@del) {
		&delete_server($d);
		}
	&webmin_log("deletes", undef, scalar(@del));
	&redirect("");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'delete_title'}, "");

	print &ui_confirmation_form(
		"delete_servs.cgi",
		&text('delete_rusure', scalar(@del)),
		[ map { [ "d", $_ ] } @del ],
		[ [ 'confirm', $text{'delete_confirm'} ] ],
		);

	&ui_print_footer("", $text{'index_return'});
	}
