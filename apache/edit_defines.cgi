#!/usr/local/bin/perl
# edit_defines.cgi
# Display a form for editing run-time httpd defines

require './apache-lib.pl';
$access{'global'}==1 || &error($text{'defines_ecannot'});
&ui_print_header(undef, $text{'defines_title'}, "",
	undef, undef, undef, undef, &restart_button());

print $text{'defines_desc'},"<p>\n";
@defs = &get_httpd_defines(1);
if (@defs) {
	print &text('defines_config',
		  "<tt><b>".join(" ", @defs)."</b></tt>"),"<p>\n";
	}

print &ui_form_start("save_defines.cgi", "post");
print &ui_table_start(undef, undef, 2);
print &ui_table_row($text{'defines_list'},
	&ui_textarea("defines",
		join("\n", split(/\s+/, $site{'defines'})), 5, 20));
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("index.cgi?mode=global", $text{'index_return2'});
