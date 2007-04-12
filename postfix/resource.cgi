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
# A form for controlling resource control.
#
# << Here are all options seen in Postfix sample-resource.cf >>

require './postfix-lib.pl';


$access{'resource'} || &error($text{'resource_ecannot'});
&ui_print_header(undef, $text{'resource_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'resource_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_freefield("bounce_size_limit", 15);
&option_freefield("command_time_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("default_process_limit", 15);
&option_freefield("duplicate_filter_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("deliver_lock_attempts", 15);
&option_freefield("deliver_lock_delay", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("fork_attempts", 15);
&option_freefield("fork_delay", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("header_size_limit", 15);
&option_freefield("line_length_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("message_size_limit", 15);
&option_freefield("qmgr_message_active_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("qmgr_message_recipient_limit", 15);
&option_freefield("queue_minfree", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("stale_lock_time", 15);
&option_freefield("transport_retry_time", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("mailbox_size_limit", 15);
print "</tr>\n";


print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});




