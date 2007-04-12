#!/usr/local/bin/perl
# run_form.cgi
# Show options for running cfengine on this host

require './cfengine-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'run_title'}, "", "run");

print "<p>$text{'run_desc'}<br>\n";

print "<form action=run.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'run_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&show_run_form();

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'run_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});


