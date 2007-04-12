#!/usr/local/bin/perl
# third_chooser.cgi
# Display a list of third-party modules for installation

require './webmin-lib.pl';
&ui_print_header(undef, );
$mods = &list_third_modules();
if (!ref($mods)) {
	print "<b>",&text('third_failed', $mods),"</b><p>\n";
	}
else {
	print "<b>$text{'third_header'}</b><br>\n";
	print "<script>\n";
	print "function select(f)\n";
	print "{\n";
	print "opener.ifield.value = f;\n";
	print "close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
	print "<table width=100%>\n";
	foreach $m (@$mods) {
		print "<tr>\n";
		print "<td><a href='' onClick='return select(\"$m->[2]\")'>$m->[0]</a></td>\n";
		print "<td>",$m->[1] eq "NONE" ? "" : $m->[1],"</td>\n";
		print "<td>$m->[3]</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
&ui_print_footer();

