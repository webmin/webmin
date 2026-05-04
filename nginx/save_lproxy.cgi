#!/usr/local/bin/perl
# Save location proxy options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'proxy_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_opt_parse("proxy_pass", $location, undef, '^(http|https)://');

&nginx_params_parse("proxy_set_header", $location);

&nginx_opt_parse("proxy_buffer_size", $location, undef, '^\d+[bkmgtp]?$');

&nginx_opt_parse("proxy_bind", $location, undef, undef,
		 sub { return &check_ipaddress($_[0]) ||
		              &check_ip6address($_[0]) ? undef :
				$text{'opt_eproxy_bind'} });

&nginx_textarea_parse("proxy_pass_header", $location, undef,
		      '^[a-zA-Z0-9\.\_\-]+$');

&nginx_textarea_parse("proxy_hide_header", $location, undef,
		      '^[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("proxy", "location", &location_path($location), 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

