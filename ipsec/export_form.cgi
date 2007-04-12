#!/usr/local/bin/perl
# export_form.cgi
# Show a form for exporting an IPsec config section to a file

require './ipsec-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'export_title'}, "");

print "<form action=export.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

@conf = &get_config();
$conn = $conf[$in{'idx'}];
print &text('export_desc', "<tt>$conn->{'value'}</tt>"),"<p>\n";

printf "<input type=radio name=mode value=0 checked> %s<br>\n",
	$text{'export_print'};
printf "<input type=radio name=mode value=1> %s\n",
	$text{'export_save'};
print "<input name=file size=30> ",&file_chooser_button("file", 0),"<p>\n";

print "<input type=submit value='$text{'export_ok'}'></form>\n";

&ui_print_footer("edit.cgi?idx=$in{'idx'}", $text{'edit_return'});

