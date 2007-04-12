#!/usr/local/bin/perl
# edit_file.cgi
# Display a form for editing the Jabber config file directly

require './jabber-lib.pl';
&ui_print_header(undef, $text{'file_title'}, "", "file");

print "$text{'file_desc'}<p>\n";

print "<form action=save_file.cgi method=post enctype=multipart/form-data>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'file_header'}</b></td> </tr>\n";
print "<tr $cb> <td><textarea name=file rows=15 cols=80>";
open(FILE, $config{'jabber_config'});
while(<FILE>) {
	print &html_escape($_);
	}
close(FILE);
print "</textarea></td> </tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

