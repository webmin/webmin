#!/usr/local/bin/perl
# edit_priv.cgi
# Display various privileged settings

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("priv");
&ui_print_header($header_subtext, $text{'priv_title'}, "");
$conf = &get_config();

print "$text{'priv_desc'}<p>\n";
&start_form("save_priv.cgi", $text{'priv_header'});

# Whitelist file path
$path = &find("auto_whitelist_path", $conf);
print &ui_table_row($text{'priv_white'},
	&opt_field("auto_whitelist_path", $path, 40,
		   "~/.spamassassin/auto-whitelist"));

# Whitelist file mode
$mode = &find("auto_whitelist_file_mode", $conf);
print &ui_table_row($text{'priv_mode'},
	&opt_field("auto_whitelist_file_mode", $mode, 4, "0700"));

# DCC options
$dcc = &find("dcc_options", $conf);
print &ui_table_row($text{'priv_dcc'},
	&opt_field("dcc_options", $dcc, 10, "-R"));

# Timing log file
$log = &find("timelog_path", $conf);
print &ui_table_row($text{'priv_log'},
	&opt_field("timelog_path", $log, 40, "NULL"));

# Razor config file
$razor = &find("razor_config", $conf);
print &ui_table_row($text{'priv_razor'},
	&opt_field("razor_config", $razor, 40, "~/razor.conf"));

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});


