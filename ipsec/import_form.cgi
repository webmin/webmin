#!/usr/local/bin/perl
# import_form.cgi
# Show a form for importing an IPsec config section from a file

require './ipsec-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'import_title'}, "");

print "<form action=import.cgi method=post enctype=multipart/form-data>\n";

print "$text{'import_desc'}<p>\n";

printf "<input type=radio name=mode value=0 checked> %s\n",
	$text{'import_upload'};
print "<input type=file name=upload><br>\n";
printf "<input type=radio name=mode value=1> %s\n",
	$text{'import_file'};
print "<input name=file size=30> ",&file_chooser_button("file", 0),"<p>\n";

print "<input type=checkbox name=over value=1> $text{'import_over'}<p>\n";

print "<input type=submit value='$text{'import_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});


