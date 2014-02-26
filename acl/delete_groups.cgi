#!/usr/local/bin/perl
# Delete a bunch of Webmin groups

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
&error_setup($text{'gdeletes_err'});
$access{'groups'} || &error($text{'gdelete_ecannot'});

# Validate inputs
my @d = split(/\0/, $in{'d'});
@d || &error($text{'udeletes_enone'});
my @glist = &list_groups();
my $ucount = 0;
foreach my $g (@d) {
	my ($group) = grep { $_->{'name'} eq $g } @glist;
	foreach my $m (@{$group->{'members'}}) {
		&error($text{'gdelete_esub'}) if ($m =~ /^\@/);
		&error($text{'gdelete_euser'}) if ($m eq $base_remote_user);
		$ucount++;
		}
	}

if ($in{'confirm'}) {
	# Do it
	foreach my $g (@d) {
		my ($group) = grep { $_->{'name'} eq $g } @glist;
		&delete_group($g);
		foreach my $u (@{$group->{'members'}}) {
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

	print &ui_confirmation_form(
		"delete_groups.cgi",
		&text('gdeletes_rusure', scalar(@d), $ucount),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'gdeletes_ok'} ] ],
		undef,
		&text('gdeletes_users', join(" ", map { "<tt>$_</tt>" } @d)),
		);

	&ui_print_footer("", $text{'index_return'});
	}

