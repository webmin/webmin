#!/usr/local/bin/perl
# Show server block logging options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
$access{'logs'} || &error($text{'logs_ecannot'});

&ui_print_header(&server_desc($server), $text{'slogs_title'}, "");

print &ui_form_start("save_slogs.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'slogs_header'}, undef, 2);

print &nginx_error_log_input("error_log", $server);

print &nginx_access_log_input("access_log", $server);

print &nginx_logformat_input("log_format", $server);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
