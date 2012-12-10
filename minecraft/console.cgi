#!/usr/local/bin/perl
# Show the console, with a command field

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();

&ui_print_header(undef, $text{'console_title'}, "");

&is_minecraft_server_running() || &error($text{'console_edown'});

print "<iframe src=output.cgi width=100% height=70%></iframe>\n";
print "<iframe src=command.cgi width=100% height=70 border=0></iframe>\n";

&ui_print_footer("", $text{'index_return'});
