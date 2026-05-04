#!/usr/local/bin/perl
# Save server block proxy options

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

&nginx_params_parse("proxy_set_header", $server);

&nginx_opt_parse("proxy_buffer_size", $server, undef, '^\d+[bkmgtp]?$');

&nginx_opt_parse("proxy_bind", $server, undef, undef,
		 sub { return &check_ipaddress($_[0]) ||
		              &check_ip6address($_[0]) ? undef :
				$text{'opt_eproxy_bind'} });

&nginx_textarea_parse("proxy_pass_header", $server, undef,
		      '^[a-zA-Z0-9\.\_\-]+$');

&nginx_textarea_parse("proxy_hide_header", $server, undef,
		      '^[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("proxy", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

