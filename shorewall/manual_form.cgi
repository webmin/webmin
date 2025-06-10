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

print &ui_form_start("manual_save.cgi", "form-data");
print &ui_hidden("table", $in{'table'});
print &ui_textarea("data", &read_file_contents($file), 20, 80);
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("list.cgi?table=$in{'table'}",
		 $text{$in{'tableclean'}."_return"});
