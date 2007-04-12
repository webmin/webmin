#!/usr/local/bin/perl
# ftpaccess.cgi
# Display a list of per-directory config files

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'ftpaccess_title'}, "",
	undef, undef, undef, undef, &restart_button());

print "$text{'ftpaccess_desc'} <p>\n";
if (@ftpaccess_files) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'ftpaccess_title'}</b></td> </tr>\n";
	print "<tr $cb><td><table width=100%>\n";
	for($i=0; $i<@ftpaccess_files; $i++) {
		if ($i%2 == 0) { print "<tr>\n"; }
		print "<td width=50%><a href=\"ftpaccess_index.cgi?file=",
		      &urlize($ftpaccess_files[$i]),"\">",
		      &html_escape($ftpaccess_files[$i]),"</a></td>\n";
		if ($i%2 == 1) { print "</tr>\n"; }
		}
	print "</table></td></tr></table><p>\n";
	}
print "<form action=create_ftpaccess.cgi>\n";
print "<input type=submit value=\"$text{'ftpaccess_create'}\">\n";
print "<input name=file size=30>\n",
	&file_chooser_button("file", 0, 0);
print "</form>\n";

print "<form action=find_ftpaccess.cgi>\n";
print "<input type=submit value=\"$text{'ftpaccess_find'}\">\n";
print "<input type=radio name=from value=0 checked> ",
      "$text{'ftpaccess_auto'}&nbsp;&nbsp;\n";
print "<input type=radio name=from value=1>\n";
print "$text{'ftpaccess_from'}\n";
print "<input name=dir size=30 value=/>\n",
	&file_chooser_button("dir", 1, 1);
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

