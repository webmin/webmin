#!/usr/local/bin/perl
# index.cgi
# Display all existing exports

require './sgiexports-lib.pl';
&header($text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("exports", "man"));
print &ui_hr();

@exports = &get_exports();
if (@exports) {
	print "<a href='edit_export.cgi?new=1'>$text{'index_add'}<br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td width=20%><b>$text{'index_dir'}</b></td> ",
	      "<td><b>$text{'index_hosts'}</b></td> </tr>\n";
	foreach $e (@exports) {
		print "<tr $cb>\n";
		print "<td><a href='edit_export.cgi?idx=$e->{'index'}'>",
		      "$e->{'dir'}</a></td>\n";
		local @h = @{$e->{'hosts'}};
		print "<td>",@h ? join(" ", @h) : $text{'index_all'},"</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print "<a href='edit_export.cgi?new=1'>$text{'index_add'}<p>\n";

print &ui_hr();
print "<table width=100%> <tr>\n";
print "<td><form action=apply.cgi>\n";
print "<input type=submit value=\"$text{'index_apply'}\">\n";
print "</form></td>\n";
print "<td valign=top>$text{'index_applymsg'}</td>\n";
print "</tr> <tr> </table>\n";

print &ui_hr();
&footer("/", $text{'index'});

