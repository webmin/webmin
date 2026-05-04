#!/usr/local/bin/perl
# Save location gzip options

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
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_onoff_parse("gzip", $location);

&nginx_opt_parse("gzip_disable", $location, undef);

&nginx_opt_parse("gzip_comp_level", $location, undef, '^[1-9]$');

&nginx_opt_list_parse("gzip_types", $location, undef,
		      '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("gzip", "location", &location_path($location),
            { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
          "&path=".&urlize($in{'path'}));
