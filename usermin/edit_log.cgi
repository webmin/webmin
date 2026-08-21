#!/usr/local/bin/perl
# Display Usermin webserver logging options

require './usermin-lib.pl';
$access{'log'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'log_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print &text('log_desc', "<tt>$miniserv{'logfile'}</tt>"),"<p>\n";
print &ui_form_start("change_log.cgi", "post");
print &ui_table_start($text{'log_header'}, undef, 2);

# Control the Usermin access log and its built-in expiry mechanism.
print &ui_table_row($text{'log_status'},
	&ui_radio("log", $miniserv{'log'} ? 1 : 0,
		  [ [ 1, $text{'log_enable'} ],
		    [ 0, $text{'log_disable'} ] ]));
print &ui_table_row($text{'log_resolv'},
	&ui_yesno_radio("loghost", int($miniserv{'loghost'})));
print &ui_table_row($text{'log_trust'},
	&ui_yesno_radio("logtrust", int($miniserv{'logtrust'})));
print &ui_table_row($text{'log_clf'},
	&ui_yesno_radio("logclf", int($miniserv{'logclf'})));
print &ui_table_row($text{'log_clear'},
	&ui_radio("logclear", int($miniserv{'logclear'}),
		  [ [ 1, &text('log_period',
			&ui_textbox("logtime", $miniserv{'logtime'}, 10)) ],
		    [ 0, $text{'no'} ] ]));

# Only systemd services can safely inherit stderr into the journal.
if (&webmin::miniserv_systemd_journal_available("usermin.service")) {
	print &ui_table_row($text{'log_error'},
		&ui_radio("error_journal", $miniserv{'errorlog'} eq '-' ? 1 : 0,
			  [ [ 0, $text{'log_error_file'} ],
			    [ 1, $text{'log_error_journal'} ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);
&ui_print_footer("", $text{'index_return'});
