#!/usr/local/bin/perl
# tunefs_form.cgi
# Display a form asking for filesystem tuning parameters

require './fdisk-lib.pl';
&can_edit_disk($in{'dev'}) || &error($text{'tunefs_ecannot'});
&ui_print_header(undef, $text{'tunefs_title'}, "");
&ReadParse();

@stat = &device_status($in{dev});
print &text('tunefs_desc', &fstype_name($in{type}), "<tt>$in{dev}</tt>",
	    "<tt>$stat[1]</tt>"),"<p>\n";

print &ui_form_start("tunefs.cgi");
print &ui_hidden("dev", $in{'dev'});
print &ui_hidden("type", $in{'type'});
print &ui_table_start($text{'tunefs_params'}, "width=100%", 4);
&tunefs_options($in{type});
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'tunefs_tune'} ] ]);

&ui_print_footer("", $text{'index_return'});

