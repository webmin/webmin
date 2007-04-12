#!/usr/local/bin/perl
# standard_chooser.cgi
# Display a list of standard modules for installation

require './webmin-lib.pl';
&ui_print_header(undef, );
$mods = &list_standard_modules();
if (!ref($mods)) {
	print "<b>",&text('standard_failed', $mods),"</b><p>\n";
	}
else {
	print "<b>$text{'standard_header'}</b><br>\n";
	if ($mods->[0]->[1] > &get_webmin_version()) {
		print &text('standard_warn', $mods->[0]->[1]),"<br>\n";
		}
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
		local $minfo = { 'os_support' => $m->[3] };
		next if (!&check_os_support($minfo));
		print "<tr>\n";
		print "<td><a href='' onClick='return select(\"$m->[0]\")'>$m->[0]</a></td>\n";
		print "<td>$m->[4]</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
&ui_print_footer();

