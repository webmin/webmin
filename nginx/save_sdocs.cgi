#!/usr/local/bin/perl
# Save document options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'docs_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&nginx_opt_parse("root", $server, undef, '^\/.*$');
$in{'root_def'} || &can_directory($in{'root'}) ||
	&error(&text('location_ecannot',
		     "<tt>".&html_escape($in{'root'})."</tt>",
		     "<tt>".&html_escape($access{'root'})."</tt>"));

&nginx_opt_parse("index", $server, undef, undef, undef, 1);

&nginx_opt_parse("default_type", $server, undef,
		 '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("sdocs", "server", $name);

&redirect("edit_server.cgi?id=".&urlize(&server_id($server)));
