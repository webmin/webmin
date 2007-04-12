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
# A form for editing address rewriting for Postfix
#
# << Here are all options seen in Postfix sample-rewrite.cf >>

require './postfix-lib.pl';


$access{'address_rewriting'} || &error($text{'address_rewriting_ecannot'});
&ui_print_header(undef, $text{'address_rewriting_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'address_rewriting_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_yesno("allow_percent_hack");
&option_yesno("append_at_myorigin");
print "</tr>\n";

print "<tr>\n";
&option_yesno("append_dot_mydomain");
&option_yesno("swap_bangpath", 'help');
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("empty_address_recipient", 20, $text{'opt_empty_recip_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("masquerade_domains", 35, $none);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("masquerade_exceptions", 35, $none);
print "</tr>\n";


print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});




