#!/usr/local/bin/perl
# Save user and process options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %access);
&lock_all_config_files();
my $parent = &get_config_parent();
my $events = &find("events", $parent);
my $http = &find("http", $parent);
&error_setup($text{'misc_err'});
$access{'global'} || &error($text{'index_eglobal'});
&ReadParse();

&nginx_user_parse("user", $parent);

&nginx_opt_parse("worker_processes", $parent, undef, '^([1-9]\d*|auto)$');

&nginx_opt_parse("worker_priority", $parent, undef, '^\-?\d+$');

&nginx_opt_parse("index", $http, undef);

&nginx_opt_parse("default_type", $http, undef,
		 '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("misc");
&redirect("");

