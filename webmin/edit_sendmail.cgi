#!/usr/local/bin/perl
# Show mail sending options

require './webmin-lib.pl';
&ui_print_header(undef, $text{'sendmail_title'}, "");
&foreign_require("mailboxes");
%mconfig = &foreign_config("mailboxes");

print $text{'sendmail_desc'},"<p>\n";

print &ui_form_start("save_sendmail.cgi", "post");
print &ui_table_start($text{'sendmail_header'}, undef, 2);

# Mail server type
$ms = $mconfig{'mail_system'};
print &ui_table_row($text{'sendmail_system'},
	$mailboxes::text{'index_system'.$ms}, undef, [ "valign=middle","valign=middle" ]);

# SMTP server
$smtp = $mconfig{'send_mode'};
$mode = $smtp eq "" ? 0 :
	$smtp eq "localhost" || $smtp eq "127.0.0.1" ? 1 : 2;
$port = ($mode == 2 ? $mconfig{'smtp_port'} : undef) || 25;
print &ui_table_row($text{'sendmail_smtp'},
	&ui_radio("mode", $mode, [ [ 0, $text{'sendmail_smtp0'}."<br>" ],
				   [ 1, $text{'sendmail_smtp1'}."<br>" ],
				   [ 2, $text{'sendmail_smtp2'} ] ]).
	" ".&ui_textbox("smtp", $mode == 2 ? $smtp : "", 40).
	" ".$text{'sendmail_port'}.
	" ".&ui_textbox("port", $port, 6), undef, [ "valign=top","valign=middle" ]);

# SMTP login and password
$user = $mconfig{'smtp_user'};
$pass = $mconfig{'smtp_pass'};
print &ui_table_row($text{'sendmail_login'},
	&ui_radio("login_def", $user ? 0 : 1,
		  [ [ 1, $text{'sendmail_login1'}."<br>" ],
		    [ 0, $text{'sendmail_login0'} ] ])." ".
	&ui_textbox("login_user", $user, 20)." ".
	$text{'sendmail_pass'}." ".
	&ui_textbox("login_pass", $pass, 20), undef, [ "valign=top","valign=middle" ]);

# Authentication method
$auth = $mconfig{'smtp_auth'};
print &ui_table_row($text{'sendmail_auth'},
	&ui_select("auth", $auth,
		   [ [ undef, $text{'default'} ],
		     "Cram-MD5", "Digest-MD5", "Plain", "Login" ]), undef, [ "valign=middle","valign=middle" ]);

# From address
$from = $mconfig{'webmin_from'};
$fromdef = "webmin\@".&mailboxes::get_from_domain();
print &ui_table_row($text{'sendmail_from'},
	&ui_opt_textbox("from", $from, 40,
			&text('sendmail_fromdef', $fromdef)."<br>",
			$text{'sendmail_fromaddr'}), undef, [ "valign=top","valign=middle" ]);

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

print &ui_hr();

print $text{'sendmail_desc2'},"<p>\n";

print &ui_form_start("test_sendmail.cgi", "post");
print &ui_table_start($text{'sendmail_header2'}, undef, 2);

print &ui_table_row($text{'sendmail_to'},
		    &ui_textbox("to", undef, 40), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'sendmail_subject'},
		    &ui_textbox("subject", "Test email from Webmin", 40), undef, [ "valign=middle","valign=middle" ]);

$msg = "This is a test message from Webmin, sent with the settings :\n".
       "\n".
       "Mail server: ".$mailboxes::text{'index_system'.$ms}."\n".
       "Sent via: ".($smtp || "Local mail server")."\n".
       "SMTP login: ".($user || "None")."\n".
       "SMTP authentication: ".($auth || "Default")."\n";
print &ui_table_row($text{'sendmail_body'},
		    &ui_textarea("body", $msg, 8, 80), undef, [ "valign=top","valign=top" ]);

print &ui_table_end();
print &ui_form_end([ [ "", $text{'sendmail_send'} ] ]);

&ui_print_footer("", $text{'index_return'});

