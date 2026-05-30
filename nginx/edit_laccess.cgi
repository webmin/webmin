#!/usr/local/bin/perl
# Show location access control options

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

&ui_print_header(&location_desc($server, $location), $text{'access_title'}, "");

print &ui_form_start("save_laccess.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("path", $in{'path'});
print &nginx_submod_hidden();
print &ui_table_start($text{'access_header'}, undef, 2);

print &nginx_access_input("allow", "deny", $location);

print &nginx_realm_input("auth_basic", $location);

print &nginx_passfile_input("auth_basic_user_file", $location,
			    $in{'id'}, $in{'path'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_location.cgi?id=".&urlize($in{'id'}).
		   "&path=".&urlize($in{'path'})),
		 $text{'location_return'},
		 &nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
