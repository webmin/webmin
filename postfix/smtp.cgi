#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# A form for SMTP client parameters.
#
# << Here are all options seen in Postfix sample-smtp.cf >>

require './postfix-lib.pl';


$access{'smtp'} || &error($text{'smtp_ecannot'});
&ui_print_header(undef, $text{'smtp_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'smtpd_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("best_mx_transport", 25, $text{'opts_best_mx_transport_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("fallback_relay", 60, $default);
print "</tr>\n";

print "<tr>\n";
&option_yesno("ignore_mx_lookup_error", 'help');
&option_yesno("smtp_skip_4xx_greeting", 'help');
print "</tr>\n";

print "<tr>\n";
&option_yesno("smtp_skip_quit_response", 'help');
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtp_destination_concurrency_limit", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtp_destination_recipient_limit", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtp_connect_timeout", 15);
&option_freefield("smtp_helo_timeout", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtp_mail_timeout", 15);
&option_freefield("smtp_rcpt_timeout", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtp_data_init_timeout", 15);
&option_freefield("smtp_data_xfer_timeout", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtp_data_done_timeout", 15);
&option_freefield("smtp_quit_timeout", 15);
print "</tr>\n";



print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});




