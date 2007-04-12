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
# << Here are all options seen in Postfix sample-rate.cf >>

require './postfix-lib.pl';


$access{'rate'} || &error($text{'rate_ecannot'});
&ui_print_header(undef, $text{'rate_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'rate_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_freefield("default_destination_concurrency_limit", 15);
&option_freefield("default_destination_recipient_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("initial_destination_concurrency", 15);
&option_freefield("maximal_queue_lifetime", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("minimal_backoff_time", 15);
&option_freefield("maximal_backoff_time", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("queue_run_delay", 15);
&option_freefield("defer_transports", 15);
print "</tr>\n";


print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});




