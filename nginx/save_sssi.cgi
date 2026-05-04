#!/usr/local/bin/perl
# Save server block server-side include

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

&nginx_onoff_parse("ssi", $server);

&nginx_onoff_parse("ssi_silent_errors", $server);

&nginx_opt_list_parse("ssi_types", $server, undef,
		      '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&nginx_opt_parse("ssi_value_length", $server, undef, '^\d+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("ssi", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

