#!/usr/local/bin/perl
# delete_group.cgi
# Delete a group (and maybe it's members)

require './acl-lib.pl';
&ReadParse();
&error_setup($text{'gdelete_err'});
$access{'groups'} || &error($text{'gdelete_ecannot'});
@glist = &list_groups();
($group) = grep { $_->{'name'} eq $in{'group'} } @glist;
@mems = @{$group->{'members'}};
foreach $m (@mems) {
	&error($text{'gdelete_esub'}) if ($m =~ /^\@/);
	}

if (&indexof($base_remote_user, @mems) >= 0) {
	&error($text{'gdelete_euser'});
	}
elsif (@mems && !$in{'confirm'}) {
	# Ask if the user really wants to delete the group and members
	&ui_print_header(undef, $text{'gdelete_title'}, "");
	print "<center><form action=delete_group.cgi>\n";
	print "<input type=hidden name=group value='$in{'group'}'>\n";
	print &text('gdelete_desc', "<tt>$in{'group'}</tt>",
		    "<tt>".join(" ", @mems)."</tt>"),"<p>\n";
	print "<input type=submit name=confirm value='$text{'gdelete_ok'}'>\n";
	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Delete the group (and members if any)
	&delete_group($in{'group'});
	foreach $u (@mems) {
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

