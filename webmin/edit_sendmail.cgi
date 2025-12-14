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
	$mailboxes::text{'index_system'.$ms});

# SMTP server
$smtp = $mconfig{'send_mode'};
$mode = $smtp eq "" ? 0 :
	$smtp eq "localhost" || $smtp eq "127.0.0.1" ? 1 : 2;
$port = $mconfig{'smtp_port'};
print &ui_table_row($text{'sendmail_smtp'},
	&ui_radio("mode", $mode, [ [ 0, $text{'sendmail_smtp0'}."<br>" ],
				   [ 1, $text{'sendmail_smtp1'}."<br>" ],
				   [ 2, $text{'sendmail_smtp2'} ] ]).
	" ".&ui_textbox("smtp", $mode == 2 ? $smtp : "", 40));


# SMTP port
print &ui_table_row($text{'sendmail_port'},
	&ui_opt_textbox("port", $port, 6, $text{'sendmail_portdef'},
					  $text{'sendmail_portsel'}));

# SMTP encryption
print &ui_table_row($text{'sendmail_ssl'},
	&ui_select("ssl", int($mconfig{'smtp_ssl'}),
		   [ [ 0, $text{'sendmail_ssl0'} ],
		     [ 1, $text{'sendmail_ssl1'} ],
		     [ 2, $text{'sendmail_ssl2'} ] ]));

# SMTP login and password
$user = $mconfig{'smtp_user'};
$pass = $mconfig{'smtp_pass'};
print &ui_table_row($text{'sendmail_login'},
	&ui_radio("login_def", $user ? 0 : 1,
		  [ [ 1, $text{'sendmail_login1'}."<br>" ],
		    [ 0, $text{'sendmail_login0'} ] ])." ".
	&ui_textbox("login_user", $user, 20)." ".
	$text{'sendmail_pass'}." ".
	&ui_textbox("login_pass", $pass, 20));

# Authentication method
$auth = $mconfig{'smtp_auth'};
print &ui_table_row($text{'sendmail_auth'},
	&ui_select("auth", $auth,
		   [ [ undef, $text{'sendmail_authdef'} ],
		     "Cram-MD5", "Digest-MD5", "Plain", "Login" ]));

# From address
$from = $mconfig{'webmin_from'};
$fromdef = "webmin-noreply\@".&mailboxes::get_from_domain();
print &ui_table_row($text{'sendmail_from'},
	&ui_opt_textbox("from", $from, 40,
			&text('sendmail_fromdef', $fromdef)."<br>",
			$text{'sendmail_fromaddr'})." ".
	$text{'sendmail_name'}." ".
	&ui_textbox("from_name", $mconfig{'webmin_from_name'}, 30), 3);

# Default to address for notifications
$to = $gconfig{'webmin_email_to'};
print &ui_table_row($text{'sendmail_toaddr'},
	&ui_opt_textbox("to", $to, 40, $text{'sendmail_to_def'}));

# URL for use in emails
$url = $gconfig{'webmin_email_url'};
$defurl = &get_webmin_email_url(undef, undef, 1);
print &ui_table_row($text{'sendmail_url'},
	&ui_opt_textbox("url", $url, 40,
			&text('sendmail_url_def', "<tt>$defurl</tt>")."<br>",
			$text{'sendmail_url_custom'}));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

print &ui_hr();

print $text{'sendmail_desc2'},"<p>\n";

print &ui_form_start("test_sendmail.cgi", "post");
print &ui_table_start($text{'sendmail_header2'}, undef, 2);

print &ui_table_row($text{'sendmail_to'},
		    &ui_textbox("to", $to, 40));

print &ui_table_row($text{'sendmail_subject'},
		    &ui_textbox("subject", "Test email from Webmin", 40));

$msg = "This is a test message from Webmin, sent with the settings :\n".
       "\n".
       "Mail server: ".$mailboxes::text{'index_system'.$ms}."\n".
       "Sent via: ".($smtp || "Local mail server")."\n".
       "SMTP login: ".($user || "None")."\n".
       "SMTP authentication: ".($auth || "Default")."\n";
print &ui_table_row($text{'sendmail_body'},
		    &ui_textarea("body", $msg, 8, 80));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'sendmail_send'} ] ]);

&ui_print_footer("", $text{'index_return'});

