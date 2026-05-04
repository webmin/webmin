#!/usr/local/bin/perl
# Save server block gzip options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'ssl_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&nginx_onoff_parse("gzip", $server);

&nginx_opt_parse("gzip_disable", $server, undef);

&nginx_opt_parse("gzip_comp_level", $server, undef, '^[1-9]$');

&nginx_opt_list_parse("gzip_types", $server, undef,
		      '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("gzip", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

