#!/usr/local/bin/perl
# Save document options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %access);
&lock_all_config_files();
my $parent = &get_config_parent();
my $http = &find("http", $parent);
&error_setup($text{'docs_err'});
$access{'global'} || &error($text{'index_eglobal'});
&ReadParse();

&nginx_opt_parse("root", $http, undef, '^\/.*$');

&nginx_opt_parse("index", $http, undef, undef, undef, 1);

&nginx_opt_parse("default_type", $http, undef,
		 '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("docs");
&redirect("");

