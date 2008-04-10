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
# A form for SMTP server parameters.
# modified by Roberto Tecchio, 2005 (www.tecchio.net)
#
# << Here are all options seen in Postfix sample-smtpd.cf >>

require './postfix-lib.pl';

$access{'smtpd'} || &error($text{'smtpd_ecannot'});
&ui_print_header(undef, $text{'smtpd_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'smtpd_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_banner", 85, $default);
print "</tr>\n";


print "<tr>\n";
&option_freefield("smtpd_recipient_limit", 15);
&option_yesno("disable_vrfy_command", 'help');
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtpd_timeout", 15);
&option_freefield("smtpd_error_sleep_time", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtpd_soft_error_limit", 15);
&option_freefield("smtpd_hard_error_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_yesno("smtpd_helo_required", 'help');
&option_yesno("allow_untrusted_routing", 'help');
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_etrn_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_helo_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_sender_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_recipient_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("relay_domains", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("access_map_reject_code", 15, $default);
&option_freefield("invalid_hostname_reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("maps_rbl_reject_code", 15, $default);
&option_freefield("reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("relay_domains_reject_code", 15, $default);
&option_freefield("unknown_address_reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("unknown_client_reject_code", 15, $default);
&option_freefield("unknown_hostname_reject_code", 15, $default);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});
   
