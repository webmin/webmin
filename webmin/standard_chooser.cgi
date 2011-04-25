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
	@table = ( );
	foreach $m (@$mods) {
		my $minfo = { 'os_support' => $m->[3] };
		next if (!&check_os_support($minfo));
		push(@table, [
		 "<a href='' onClick='return select(\"$m->[0]\")'>$m->[0]</a>",
		 &html_escape($m->[4]),
		 ]);
		}
	print &ui_columns_table(undef, 100, \@table);
	}
&ui_print_footer();

