#!/usr/local/bin/perl
# Delete a bunch of Webmin users

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
&error_setup($text{'udeletes_err'});
$access{'delete'} || &error($text{'delete_ecannot'});

# Validate inputs
my @d = split(/\0/, $in{'d'});
@d || &error($text{'udeletes_enone'});
foreach my $user (@d) {
	&can_edit_user($user) || &error($text{'delete_euser'});
	if ($base_remote_user eq $user) {
		&error($text{'delete_eself'});
		}
	my $uinfo = &get_user($user);
	$uinfo->{'readonly'} && &error($text{'udeletes_ereadonly'});
	}

if ($in{'confirm'}) {
	# Do it
	foreach my $user (@d) {
		&delete_user($user);
		&delete_from_groups($user);
		}

	&reload_miniserv();
	&webmin_log("delete", "users", scalar(@d));
	&redirect("");
	}
else {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'udeletes_title'}, "");

	print &ui_confirmation_form(
		"delete_users.cgi",
		&text('udeletes_rusure', scalar(@d)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'udeletes_ok'} ] ],
		&text('udeletes_users', join(" ", map { "<tt>$_</tt>" } @d)),
		);
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

