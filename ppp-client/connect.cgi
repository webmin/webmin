#!/usr/local/bin/perl
# connect.cgi
# Attempt a connection to the Internet with wvdial, and show the results

require './ppp-client-lib.pl';
&ReadParse();
$theme_no_table++;
$| = 1;
&ui_print_header(undef, $text{'connect_title'}, "");

$connected = &ppp_connect($in{'section'}, 0);
&webmin_log("connect", $in{'section'}, $connected);

&ui_print_footer("", $text{'index_return'});


