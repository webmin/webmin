#!/usr/local/bin/perl
# Show document related options for a server block

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'sdocs_title'}, "");

print &ui_form_start("save_sdocs.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &nginx_submod_hidden();
print &ui_table_start($text{'docs_header'}, undef, 2);

print &nginx_opt_input("root", $server, 60, undef,
		       &file_chooser_button("root", 1));

print &nginx_opt_input("index", $server, 60, undef, undef, 1);

print &nginx_opt_input("default_type", $server, 20);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&nginx_submod_url("edit_server.cgi?id=".&urlize($in{'id'})),
		 $text{'server_return'});
