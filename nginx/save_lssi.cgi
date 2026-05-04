#!/usr/local/bin/perl
# Save location-level server-side includes

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'ssi_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_onoff_parse("ssi", $location);

&nginx_onoff_parse("ssi_silent_errors", $location);

&nginx_opt_list_parse("ssi_types", $location, undef,
		      '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&nginx_opt_parse("ssi_value_length", $location, undef, '^\d+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("ssi", "location", &location_path($location), 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

