#!/usr/local/bin/perl
# Show options related to session handling

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'session_title'}, "");

print &ui_form_start("save_session.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'session_header'}, "width=100%", 2);

# Session saving handler
print &ui_table_row($text{'session_handler'},
	&ui_select("session.save_handler",
		   &find_value("session.save_handler", $conf),
		   [ [ "files", $text{'session_files'} ],
		     [ "mm", $text{'session_mm'} ],
		     [ "users", $text{'session_users'} ] ]));

# Where to save session files
print &ui_table_row($text{'session_path'},
	&ui_opt_textbox("session.save_path",
			&find_value("session.save_path", $conf),
			60, $text{'default'}." (<tt>/tmp</tt>)"));

# Use cookies for sessions?
print &ui_table_row($text{'session_cookies'},
	&onoff_radio("session.use_cookies"));
print &ui_table_row($text{'session_only_cookies'},
	&onoff_radio("session.use_only_cookies"));

# Cookie lifetime
$lf = &find_value("session.cookie_lifetime", $conf);
print &ui_table_row($text{'session_life'},
	&ui_opt_textbox("session.cookie_lifetime", $lf || undef,
			5, $text{'session_forever'})." ".$text{'db_s'});

# Session lifetime
$lf = &find_value("session.gc_maxlifetime", $conf);
print &ui_table_row($text{'session_maxlife'},
	&ui_opt_textbox("session.gc_maxlifetime", $lf || undef,
			5, $text{'session_forever'})." ".$text{'db_s'});

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
