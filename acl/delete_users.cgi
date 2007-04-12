#!/usr/local/bin/perl
# Delete a bunch of Webmin users

require './acl-lib.pl';
&ReadParse();
&error_setup($text{'udeletes_err'});
$access{'delete'} || &error($text{'delete_ecannot'});

# Validate inputs
@d = split(/\0/, $in{'d'});
@d || &error($text{'udeletes_enone'});
foreach $user (@d) {
	&can_edit_user($user) || &error($text{'delete_euser'});
	if ($base_remote_user eq $user) {
		&error($text{'delete_eself'});
		}
	$user->{'readonly'} && &error($text{'udeletes_ereadonly'});
	}

if ($in{'confirm'}) {
	# Do it
	foreach $user (@d) {
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

	print "<center>\n";
	print &ui_form_start("delete_users.cgi", "post");
	foreach $user (@d) {
		print &ui_hidden("d", $user),"\n";
		}
	print &text('udeletes_rusure', scalar(@d)),"<p>\n";

	print &ui_form_end([ [ "confirm", $text{'udeletes_ok'} ] ]);

	print &text('udeletes_users', join(" ", map { "<tt>$_</tt>" } @d)),
	      "<p>\n";
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

