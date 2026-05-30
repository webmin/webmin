#!/usr/local/bin/perl
# Show server block proxy options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'proxy_title'}, "");

print &ui_form_start("save_sproxy.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'proxy_header'}, undef, 2);

print &nginx_opt_input("proxy_buffer_size", $server, 10,
		       $text{'fcgi_buffer'});

print &nginx_opt_input("proxy_bind", $server, 20,
		       $text{'proxy_ip'});

print &nginx_param_input("proxy_set_header", $server,
			 $text{'proxy_name'}, $text{'proxy_value'});

print &nginx_textarea_input("proxy_pass_header", $server, 60, 5);

print &nginx_textarea_input("proxy_hide_header", $server, 60, 5);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
