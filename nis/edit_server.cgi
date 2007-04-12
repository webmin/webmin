#!/usr/local/bin/perl
# edit_server.cgi
# Display NIS server settings

require './nis-lib.pl';
&ui_print_header(undef, $text{'server_title'}, "");

if (!(&get_nis_support() & 2)) {
	print "<p>$text{'server_enis'}<p>\n";
	}
else {
	print "<form action=save_server.cgi method=post>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'server_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	&show_server_config();

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'server_ok'}'></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

