#!/usr/local/bin/perl
# conf_misc.cgi
# Display other options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_misc'};

&ui_print_header(undef, $text{'misc_title'}, "");

&get_share("global");

print &ui_form_start("save_misc.cgi", "post");
print &ui_table_start($text{'misc_title'}, undef, 2);

print &ui_table_row($text{'misc_debug'},
	&ui_select("debug_level", &getval("debug level"),
		   [ [ "", $text{'default'} ],
		     (0 .. 10) ]));

print &ui_table_row($text{'misc_cachecall'},
	&yesno_input("getwd cache"));

print &ui_table_row($text{'misc_lockdir'},
	&ui_opt_textbox("lock_directory", &getval("lock directory"),
			50, $text{'default'})." ".
	&file_chooser_button("lock_directory", 1));

print &ui_table_row($text{'misc_log'},
	&ui_opt_textbox("log_file", &getval("log file"), 50, $text{'default'}).
	" ".&file_chooser_button("log_file", 0));

print &ui_table_row($text{'misc_maxlog'},
	&ui_opt_textbox("max_log_size", &getval("max log size"), 10,
			$text{'default'})." kB");

print &ui_table_row($text{'misc_rawread'},
	&yesno_input("read raw"));

print &ui_table_row($text{'misc_rawwrite'},
	&yesno_input("write raw"));

print &ui_table_row($text{'misc_overlapread'},
	&ui_opt_textbox("read_size", &getval("read size"), 10,
			$text{'default'})." ".$text{'config_bytes'});

print &ui_table_row($text{'misc_chroot'},
	&ui_opt_textbox("root_directory", &getval("root directory"), 50,
			$text{'config_none'})." ".
	&file_chooser_button("root_directory", 1));

print &ui_table_row($text{'misc_smbrun'},
	&ui_opt_textbox("smbrun", &getval("smbrun"), 50, $text{'default'})." ".
	&file_chooser_button("smbrun", 0));

print &ui_table_row($text{'misc_clienttime'},
	&ui_opt_textbox("time_offset", &getval("time offset"), 10,
			$text{'default'})." ".$text{'config_mins'});

print &ui_table_row($text{'misc_readprediction'},
	&yesno_input("read prediction"));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});


