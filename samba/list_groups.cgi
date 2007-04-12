#!/usr/local/bin/perl
# list_group.cgi
# List all existing Samba groups

require './samba-lib.pl';
%access = &get_module_acl();
$access{'maint_groups'} || &error($text{'groups_ecannot'});
&ui_print_header(undef, $text{'groups_title'}, "");

&check_group_enabled($text{'groups_cannot'});

@groups = &list_groups();
if (@groups) {
	@groups = sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @groups
		if ($config{'sort_mode'});
	print "<a href='edit_group.cgi?new=1'>$text{'groups_add'}</a><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'groups_name'}</b></td> ",
	      "<td><b>$text{'groups_unix'}</b></td> ",
	      "<td><b>$text{'groups_type'}</b></td> ",
	      "<td><b>$text{'groups_sid'}</b></td> </tr>\n";
	foreach $g (@groups) {
		print "<tr $cb>\n";
		print "<td><a href='edit_group.cgi?idx=$g->{'index'}'>",
		      "$g->{'name'}</a></td>\n";
		print "<td>",$g->{'unix'} == -1 ? $text{'groups_nounix'} :
			     "<tt>$g->{'unix'}</tt>","</td>\n";
		print "<td>",$text{'groups_type_'.$g->{'type'}} ||
			     $g->{'type'},"</td>\n";
		print "<td><tt>$g->{'sid'}</tt></td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'groups_none'}</b><p>\n";
	}
print "<a href='edit_group.cgi?new=1'>$text{'groups_add'}</a><p>\n";

&ui_print_footer("", $text{'index_sharelist'});

