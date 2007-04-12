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
# A form for controlling local delivery.
#
# << Here are all options seen in Postfix sample-local.cf >>

require './postfix-lib.pl';


$access{'local_delivery'} || &error($text{'local_delivery_ecannot'});
&ui_print_header(undef, $text{'local_delivery_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'local_delivery_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("local_transport", 30, $text{'opts_local_transport_local'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("local_command_shell", 40, $text{'opts_local_command_shell_direct'});
print "</tr>\n";

print "<tr>\n";
&option_freefield("forward_path", 80);
print "</tr>\n";

print "<tr>\n";
&option_freefield("allow_mail_to_commands", 40);
print "</tr>\n";

print "<tr>\n";
&option_freefield("allow_mail_to_files", 40);
print "</tr>\n";

print "<tr>\n";
&option_freefield("default_privs", 25);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("home_mailbox", 40, $text{'opts_home_mailbox_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("luser_relay", 40, $text{'opts_luser_relay_none'});
print "</tr>\n";

print "<tr>\n";
&option_freefield("mail_spool_directory", 40);
print "</tr>\n";

print "<tr>\n";
&option_freefield("mailbox_command", 60, $text{'opts_mailbox_command_none'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("mailbox_transport", 40, $text{'opts_mailbox_transport_none'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("fallback_transport", 40, $text{'opts_fallback_transport_none'});
print "</tr>\n";

print "<tr>\n";
&option_freefield("local_destination_concurrency_limit", 40);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("local_destination_recipient_limit", 40, $text{'opts_local_destination_recipient_limit_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("prepend_delivered_header", 40, $text{'opts_prepend_delivered_header_default'});
print "</tr>\n";


print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});




