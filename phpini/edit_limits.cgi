#!/usr/local/bin/perl
# Show options related to memory / disk limits

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'limits_title'}, "");

print &ui_form_start("save_limits.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'limits_header'}, "width=100%", 4);

# Memory limit
print &ui_table_row(&opt_help($text{'limits_mem'}, 'memory_limit'),
	&ui_opt_textbox("memory_limit",
			&find_value("memory_limit", $conf),
			8, $text{'default'}));

# POST limit
print &ui_table_row(&opt_help($text{'limits_post'}, 'post_max_size'),
	&ui_opt_textbox("post_max_size",
			&find_value("post_max_size", $conf),
			8, $text{'default'}));

# Upload limit
print &ui_table_row(&opt_help($text{'limits_upload'}, 'upload_max_filesize'),
	&ui_opt_textbox("upload_max_filesize",
			&find_value("upload_max_filesize", $conf),
			8, $text{'default'}));

# Max run time
print &ui_table_row(&opt_help($text{'limits_exec'}, 'max_execution_time'),
	&ui_opt_textbox("max_execution_time",
			&find_value("max_execution_time", $conf),
			8, $text{'default'})." ".$text{'db_s'});

# Max parsing time
print &ui_table_row(&opt_help($text{'limits_input'}, 'max_input_time'),
	&ui_opt_textbox("max_input_time",
			&find_value("max_input_time", $conf),
			8, $text{'default'})." ".$text{'db_s'});

# Max parsing time
print &ui_table_row(&opt_help($text{'limits_vars'}, 'max_input_vars'),
	&ui_opt_textbox("max_input_vars",
			&find_value("max_input_vars", $conf),
			8, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
