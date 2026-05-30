#!/usr/local/bin/perl
# Show server block server-side include options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'ssi_title'}, "");

print &ui_form_start("save_sssi.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'ssi_header'}, undef, 2);

print &nginx_onoff_input("ssi", $server);

print &nginx_onoff_input("ssi_silent_errors", $server);

print &nginx_opt_list_input("ssi_types", $server, 60, $text{'ssi_types'});

print &nginx_opt_input("ssi_value_length", $server, 10);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
