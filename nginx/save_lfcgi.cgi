#!/usr/local/bin/perl
# Save location FastCGI options

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
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_opt_parse("fastcgi_pass", $location, undef,
		 '^([a-zA-Z0-9\.\_\-]+:[0-9]+|unix:\/\S+)$');

&nginx_opt_parse("fastcgi_index", $location, undef, '^\S+$');

&nginx_params_parse("fastcgi_param", $location);

&nginx_opt_parse("fastcgi_buffer_size", $location, undef, '^\d+[bkmgtp]?$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("fcgi", "location", &location_path($location), 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

