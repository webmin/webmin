#!/usr/local/bin/perl
# manual_form.cgi
# Display the .procmailrc file

require './procmail-lib.pl';
&ui_print_header(undef, $text{'manual_title'}, "");

print &text('manual_desc', "<tt>$procmailrc</tt>"),"<p>\n";
print "<form action=manual_save.cgi method=post enctype=multipart/form-data>\n";
print "<textarea name=data rows=20 cols=80>";
open(FILE, $procmailrc);
while(<FILE>) { print &html_escape($_); }
close(FILE);
print "</textarea><br>\n";
print "<input type=submit value='$text{'save'}'>\n";

&ui_print_footer("", $text{'index_return'});


