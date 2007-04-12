#!/usr/local/bin/perl
# Show options related for PHP safe mode

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'safe_title'}, "");

print &ui_form_start("save_safe.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'safe_header'}, "width=100%", 2);

# Enable safe mode
print &ui_table_row($text{'safe_on'},
	&onoff_radio("safe_mode"));

print &ui_table_row($text{'safe_gid'},
	&onoff_radio("safe_mode_gid"));

# Safe directory for includes
print &ui_table_row($text{'safe_include'},
	&ui_opt_textbox("safe_mode_include_dir",
			&find_value("safe_mode_include_dir", $conf),
			60, $text{'safe_none'})." ".
	&file_chooser_button("safe_mode_include_dir", 1));

# Safe directory for execs
print &ui_table_row($text{'safe_exec'},
	&ui_opt_textbox("safe_mode_exec_dir",
			&find_value("safe_mode_exec_dir", $conf),
			60, $text{'safe_none'})." ".
	&file_chooser_button("safe_mode_exec_dir", 1));

# Allowed directory for opens
print &ui_table_row($text{'safe_basedir'},
	&ui_opt_textbox("open_basedir",
			&find_value("open_basedir", $conf),
			60, $text{'safe_none'})." ".
	&file_chooser_button("open_basedir", 1));



print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
