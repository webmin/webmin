#!/usr/local/bin/perl
# index.cgi
# Display the help search form

require './help-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

print "<form action=search.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'index_terms'}</b></td>\n";
print "<td><input name=terms size=50></td> </tr>\n";
print "<tr> <td valign=top><b>$text{'index_mods'}</b></td>\n";
print "<td><input type=radio name=all value=1 checked> $text{'index_all'}\n";
print "&nbsp;<input type=radio name=all value=0> $text{'index_sel'}<br>\n";
print "&nbsp;&nbsp;&nbsp;<select name=mods size=5 multiple>\n";
foreach $m (&list_modules()) {
	printf "<option value=%s>%s</option>\n",
		$m->[0], $m->[1]->{'desc'};
	}
print "</select></td> </tr>\n";
print "<tr> <td colspan=2 align=right>",
      "<input type=reset value=\"$text{'index_reset'}\">\n",
      "<input type=submit value=\"$text{'index_search'}\"></td> </tr>\n";
print "</table></td></tr></table></form>\n";

&ui_print_footer("/", $text{'index'});

