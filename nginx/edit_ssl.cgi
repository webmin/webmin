#!/usr/local/bin/perl
# Show server block SSL options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'ssl_title'}, "");

print &ui_form_start("save_ssl.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'ssl_header'}, undef, 2);

print &nginx_opt_input("ssl_certificate", $server, 50, $text{'ssl_file'},
		       &file_chooser_button("ssl_certificate"));

print &nginx_opt_input("ssl_certificate_key", $server, 50, $text{'ssl_file'},
		       &file_chooser_button("ssl_certificate_key"));

print &nginx_opt_input("ssl_ciphers", $server, 30, $text{'ssl_clist'});

print &nginx_multi_input("ssl_protocols", $server,
			 [ "SSLv2", "SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2", "TLSv1.3" ]);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
