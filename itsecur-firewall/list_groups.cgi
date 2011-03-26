#!/usr/bin/perl
# list_groups.cgi
# Displays a list of host and network groups

require './itsecur-lib.pl';
&can_use_error("groups");
&header($text{'groups_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

@groups = &list_groups();
$edit = &can_edit("groups");
if (@groups) {
	print "<a href='edit_group.cgi?new=1'>$text{'groups_add'}</a><br>\n"
		if ($edit);
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'group_name'}</b></td> ",
	      "<td><b>$text{'group_members'}</b></td> </tr>\n";
	foreach $g (@groups) {
		print "<tr $cb>\n";
		print "<td><a href='edit_group.cgi?idx=$g->{'index'}'>",
		      "$g->{'name'}</a></td>\n";
		@mems = @{$g->{'members'}};
		if (@mems > 5) {
			@mems = (@mems[0..4], "...");
			}
		print "<td>",join(" , ",
				  map { &group_name($_) } @mems),"</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'groups_none'}</b><p>\n";
	}
print "<a href='edit_group.cgi?new=1'>$text{'groups_add'}</a><p>\n"
	if ($edit);

print "<hr>\n";
&footer("", $text{'index_return'});
