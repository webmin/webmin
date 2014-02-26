#!/usr/local/bin/perl
# delete_group.cgi
# Delete a group (and maybe it's members)

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
&error_setup($text{'gdelete_err'});
$access{'groups'} || &error($text{'gdelete_ecannot'});
my @glist = &list_groups();
my ($group) = grep { $_->{'name'} eq $in{'group'} } @glist;
my @mems = @{$group->{'members'}};
foreach my $m (@mems) {
	&error($text{'gdelete_esub'}) if ($m =~ /^\@/);
	}

if (&indexof($base_remote_user, @mems) >= 0) {
	&error($text{'gdelete_euser'});
	}
elsif (@mems && !$in{'confirm'}) {
	# Ask if the user really wants to delete the group and members
	&ui_print_header(undef, $text{'gdelete_title'}, "");

	print &ui_confirmation_form(
		"delete_group.cgi",
		&text('gdelete_desc', "<tt>$in{'group'}</tt>",
                    "<tt>".join(" ", @mems)."</tt>"),
		[ [ "group", $in{'group'} ] ],
		[ [ "confirm", $text{'gdelete_ok'} ] ],
		);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Delete the group (and members if any)
	&delete_group($in{'group'});
	foreach my $u (@mems) {
		if ($u =~ /^\@(.*)/) {
			&delete_group("$1");
			}
		else {
			&delete_user($u);
			}
		}
	&delete_from_groups("\@".$in{'group'});
	&reload_miniserv();
	&webmin_log("delete", "group", $in{'group'});
	&redirect("");
	}

