#!/usr/local/bin/perl
# third_chooser.cgi
# Display a list of third-party modules for installation

$trust_unknown_referers = 1;
require './webmin-lib.pl';
&popup_header($text{'third_title'});
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
	@table = ( );
	foreach $m (@$mods) {
		push(@table, [
		 "<a href='' onClick='return select(\"$m->[2]\")'>$m->[0]</a>",
		 $m->[1] eq "NONE" ? "" : &html_escape($m->[1]),
		 $m->[3],
		 ]);
		}
	print &ui_columns_table(undef, 100, \@table);
	}
&popup_footer();

