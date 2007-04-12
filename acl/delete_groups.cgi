#!/usr/local/bin/perl
# Delete a bunch of Webmin groups

require './acl-lib.pl';
&ReadParse();
&error_setup($text{'gdeletes_err'});
$access{'groups'} || &error($text{'gdelete_ecannot'});

# Validate inputs
@d = split(/\0/, $in{'d'});
@d || &error($text{'udeletes_enone'});
@glist = &list_groups();
$ucount = 0;
foreach $g (@d) {
	($group) = grep { $_->{'name'} eq $g } @glist;
	foreach $m (@{$group->{'members'}}) {
		&error($text{'gdelete_esub'}) if ($m =~ /^\@/);
		&error($text{'gdelete_euser'}) if ($m eq $base_remote_user);
		$ucount++;
		}
	}

if ($in{'confirm'}) {
	# Do it
	foreach $g (@d) {
		($group) = grep { $_->{'name'} eq $g } @glist;
		&delete_group($g);
		foreach $m (@{$group->{'members'}}) {
			if ($u =~ /^\@(.*)/) {
				&delete_group("$1");
				}
			else {
				&delete_user($u);
				}
			}
		&delete_from_groups("\@".$g);
		}

	&reload_miniserv();
	&webmin_log("delete", "groups", scalar(@d));
	&redirect("");
	}
else {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'gdeletes_title'}, "");

	print "<center>\n";
	print &ui_form_start("delete_groups.cgi", "post");
	foreach $g (@d) {
		print &ui_hidden("d", $g),"\n";
		}
	print &text('gdeletes_rusure', scalar(@d), $ucount),"<p>\n";

	print &ui_form_end([ [ "confirm", $text{'gdeletes_ok'} ] ]);

	print &text('gdeletes_users', join(" ", map { "<tt>$_</tt>" } @d)),
	      "<p>\n";
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

