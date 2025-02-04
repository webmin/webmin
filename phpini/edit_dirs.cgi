#!/usr/local/bin/perl
# Show options for program directories and directory limits

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'dirs_title'}, "");

print &ui_form_start("save_dirs.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'dirs_header'}, "width=100%", 2);

# Include files directories
$include = &find_value("include_path", $conf);
print &ui_table_row(&opt_help($text{'dirs_include'}, 'include'),
	&ui_radio("include_def", $include ? 0 : 1,
		  [ [ 1, $text{'default'} ], [ 0, $text{'dirs_below'} ] ]).
	"<br>\n".
	&ui_textarea("include", join("\n", split(/:/, $include)), 3, 60)." ".
	&file_chooser_button("include", 1, undef, undef, 1));

# Can accept uploads?
print &ui_table_row(&opt_help($text{'dirs_upload'}, 'file_uploads'),
	&onoff_radio("file_uploads"));

# Upload temp files directory
print &ui_table_row($text{'dirs_utmp'},
	&ui_opt_textbox("utmp", &find_value("upload_tmp_dir", $conf),
			60, $text{'default'})." ".
	&file_chooser_button("utmp", 1));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
