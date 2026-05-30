#!/usr/local/bin/perl
# Show server block FCGI options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'fcgi_title'}, "");

print &ui_form_start("save_fcgi.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'fcgi_header'}, undef, 2);

# XXX should be in location section
#print &nginx_opt_input("fastcgi_pass", $server, 50, $text{'fcgi_hostport'});

print &nginx_opt_input("fastcgi_index", $server, 20, $text{'fcgi_index'});

print &nginx_param_input("fastcgi_param", $server);

print &nginx_opt_input("fastcgi_buffer_size", $server, 10,
		       $text{'fcgi_buffer'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
