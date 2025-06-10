#!/usr/local/bin/perl
# change_rl.cgi
# Switch to a different runlevel with the telinit command

require './init-lib.pl';
&ReadParse();
$access{'bootup'} == 1 || &error($text{'change_ecannot'});

&ui_print_header(undef, $text{'change_title'}, "");

$cmd = "telinit '$in{'level'}'";
print "<p>",&text('change_cmd', $in{'level'}, "<tt>$cmd</tt>"),"<p>\n";
&system_logged("$cmd </dev/null >/dev/null 2>&1 &");
&webmin_log("telinit", $in{'level'});

&ui_print_footer("", $text{'index_return'});

