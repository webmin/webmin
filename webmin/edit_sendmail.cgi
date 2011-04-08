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
print &ui_table_row($text{'sendmail_smtp'},
	&ui_radio("mode", $mode, [ [ 0, $text{'sendmail_smtp0'}."<br>" ],
				   [ 1, $text{'sendmail_smtp1'}."<br>" ],
				   [ 2, $text{'sendmail_smtp2'} ] ]).
	" ".&ui_textbox("smtp", $mode == 2 ? $smtp : "", 40));

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
		   [ [ undef, $text{'default'} ],
		     "Cram-MD5", "Digest-MD5", "Plain", "Login" ]));

# From address
$from = $mconfig{'webmin_addr'};
$fromdef = "webmin\@".&get_system_hostname();
print &ui_table_row($text{'sendmail_from'},
	&ui_opt_textbox("from", $from, 40,
			&text('sendmail_fromdef', $fromdef)."<br>",
			$text{'sendmail_fromaddr'}));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

