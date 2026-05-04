#!/usr/local/bin/perl
# Save location access control

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
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_access_parse("allow", "deny", $location);

&nginx_realm_parse("auth_basic", $location);

&nginx_passfile_parse("auth_basic_user_file", $location);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("access", "location", &location_path($location), 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

