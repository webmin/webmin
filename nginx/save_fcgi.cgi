#!/usr/local/bin/perl
# Save server block FastCGI options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'fcgi_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&nginx_opt_parse("fastcgi_index", $server, undef, '^\S+$');

&nginx_params_parse("fastcgi_param", $server);

&nginx_opt_parse("fastcgi_buffer_size", $server, undef, '^\d+[bkmgtp]?$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("fcgi", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

