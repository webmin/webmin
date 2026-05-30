#!/usr/local/bin/perl
# Show server block gzip options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'gzip_title'}, "");

print &ui_form_start("save_sgzip.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'gzip_header'}, undef, 2);

print &nginx_onoff_input("gzip", $server);

print &nginx_opt_input("gzip_disable", $server, 60, $text{'net_regexp'});

print &nginx_opt_input("gzip_comp_level", $server, 5,
		       $text{'gzip_level'});

print &nginx_opt_list_input("gzip_types", $server, 60, $text{'ssi_types'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
