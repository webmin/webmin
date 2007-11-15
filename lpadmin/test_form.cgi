#!/usr/local/bin/perl
# test_form.cgi
# Display options for printing a test page

require './lpadmin-lib.pl';
&ReadParse();
$access{'test'} || &error($text{'test_ecannot'});
&ui_print_header(&text('jobs_on', "<tt>$in{'name'}</tt>"),
		 $text{'test_title'}, "");

print "<form action=test_print.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print &text('test_desc', "<tt>$in{'name'}</tt>"),"<p>\n";

print "<input type=radio name=mode value=0 checked> $text{'test_0'}<br>\n";
print "<input type=radio name=mode value=1> $text{'test_1'}<br>\n";
print "<input type=radio name=mode value=2> $text{'test_2'}<br>\n";
print "<input type=radio name=mode value=3> $text{'test_3'} ",
      "<input type=file name=file><p>\n";

print "<input type=submit value='$text{'test_print'}'></form>\n";
&ui_print_footer("", $text{'index_return'});

