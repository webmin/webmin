#!/usr/local/bin/perl
# Save server block access control

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'access_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&nginx_access_parse("allow", "deny", $server);

&nginx_realm_parse("auth_basic", $server);

&nginx_passfile_parse("auth_basic_user_file", $server);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("access", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

