#!/usr/local/bin/perl
# Save location rewrite options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %rewrite);
&lock_all_config_files();
&error_setup($text{'rewrite_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_rewrite_parse("rewrite", $location);

&nginx_onoff_parse("rewrite_log", $location);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("rewrite", "location", &location_path($location), 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

