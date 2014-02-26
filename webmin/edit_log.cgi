#!/usr/local/bin/perl
# edit_log.cgi
# Logging config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'log_title'}, "");
&foreign_require("acl", "acl-lib.pl");
&get_miniserv_config(\%miniserv);

print &text('log_desc', "<tt>$miniserv{'logfile'}</tt>"),"<p>\n";
print &text('log_desc2', "<tt>$webmin_logfile</tt>"),"<p>\n";

print &ui_form_start("change_log.cgi", "post");
print &ui_table_start($text{'log_header'}, undef, 2);

# Is logging enabled?
print &ui_table_row($text{'log_status'},
	&ui_radio("log", $miniserv{'log'} ? 1 : 0,
		  [ [ 1, $text{'log_enable'} ],
		    [ 0, $text{'log_disable'} ] ]), undef, [ "valign=middle","valign=middle" ]);

# Log resolved hostnames
print &ui_table_row($text{'log_resolv'},
	&ui_yesno_radio("loghost", int($miniserv{'loghost'})), undef, [ "valign=middle","valign=middle" ]);

# Use common log format
print &ui_table_row($text{'log_clf'},
	&ui_yesno_radio("logclf", int($miniserv{'logclf'})), undef, [ "valign=middle","valign=middle" ]);

# Clear logs regularly
print &ui_table_row($text{'log_clear2'},
	&ui_radio("logclear", int($miniserv{'logclear'}),
		  [ [ 1, &text('log_period',
			&ui_textbox("logtime", $miniserv{'logtime'}, 10)) ],
		    [ 0, $text{'no'} ] ]), undef, [ "valign=middle","valign=middle" ]);

# Webmin users to log for
print &ui_table_row($text{'log_forusers'},
	&ui_radio("uall", $gconfig{'logusers'} ? 0 : 1,
		  [ [ 1, $text{'log_uall'} ], [ 0, $text{'log_users'} ] ]).
	"<br>\n".
	&ui_select("users", [ split(/\s+/, $gconfig{'logusers'}) ],
		   [ map { [ $_->{'name'} ] }
			 sort { $a->{'name'} cmp $b->{'name'} } 
			      &acl::list_users() ],
		   5, 1), undef, [ "valign=top","valign=middle" ]);

# Modules to log in
print &ui_table_row($text{'log_inmods'},
	&ui_radio("mall", $gconfig{'logmodules'} ? 0 : 1,
		  [ [ 1, $text{'log_mall'} ], [ 0, $text{'log_modules'} ] ]).
	"<br>\n".
	&ui_select("modules", [ split(/\s+/, $gconfig{'logmodules'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] }
			 grep { -r &module_root_directory($_)."/log_parser.pl" }
			      sort { $a->{'desc'} cmp $b->{'desc'} }
				   &get_all_module_infos() ],
		   5, 1), undef, [ "valign=top","valign=middle" ]);

# Log logins and logouts?
if (!$miniserv{'login_script'} ||
    $miniserv{'login_script'} eq $record_login_cmd) {
	print &ui_table_row($text{'log_login'},
		&ui_yesno_radio("login",
		    $miniserv{'login_script'} eq $record_login_cmd), undef, [ "valign=middle","valign=middle" ]);
	}

print &ui_table_row($text{'log_files'},
	&ui_yesno_radio("logfiles", int($gconfig{'logfiles'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'log_fullfiles'},
	&ui_yesno_radio("logfullfiles", int($gconfig{'logfullfiles'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'log_perms'},
	&ui_opt_textbox("perms", $gconfig{'logperms'}, 5, $text{'default'}), undef, [ "valign=middle","valign=middle" ]);

eval "use Sys::Syslog qw(:DEFAULT setlogsock)";
if (!$@) {
	print &ui_table_row($text{'log_syslog'},
		&ui_yesno_radio("logsyslog", int($gconfig{'logsyslog'})), undef, [ "valign=middle","valign=middle" ]);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

