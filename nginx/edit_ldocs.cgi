#!/usr/local/bin/perl
# Show document related options for a location

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&ui_print_header(&location_desc($server, $location), $text{'ldocs_title'}, "");

print &ui_form_start("save_ldocs.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("path", $in{'path'});
print &nginx_submod_hidden();
print &ui_table_start($text{'docs_header'}, undef, 2);

print &nginx_opt_input("index", $location, 60);

print &nginx_opt_input("default_type", $location, 20);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_location.cgi?id=".&urlize($in{'id'}).
		   "&path=".&urlize($in{'path'})),
		 $text{'location_return'},
		 &nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
