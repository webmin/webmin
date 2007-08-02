#!/usr/bin/perl
# Display the contents of a table file

require './shorewall-lib.pl';
&ReadParse();
&get_clean_table_name(\%in);
&can_access($in{'table'}) || &error($text{'list_ecannot'});
&ui_print_header(undef, $text{$in{'tableclean'}."_title"}, "");

$file = "$config{'config_dir'}/$in{'table'}";
$in{'table'} =~ /\.\./ && &error($text{'manual_efile'});
print &text('manual_desc', "<tt>$file</tt>"),"<p>\n";

print "<form action=manual_save.cgi method=post enctype=multipart/form-data>\n";
print &ui_hidden("table", $in{'table'});
print "<textarea name=data rows=20 cols=80>";
open(FILE, $file);
while(<FILE>) {
	print &html_escape($_);
	}
close(FILE);
print "</textarea><br>\n";
print "<input type=submit value='$text{'save'}'>\n";
print "<input type=reset value='$text{'manual_reset'}'>\n";
print "</form>\n";

&ui_print_footer("list.cgi?table=$in{'table'}", $text{$in{'tableclean'}."_return"});
