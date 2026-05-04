#!/usr/local/bin/perl
# Save logging options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %access);
&lock_all_config_files();
my $parent = &get_config_parent();
my $http = &find("http", $parent);
&error_setup($text{'logs_err'});
$access{'global'} || &error($text{'index_eglobal'});
&ReadParse();

&nginx_error_log_parse("error_log", $parent);

&nginx_access_log_parse("access_log", $http);

&nginx_opt_parse("pid", $parent, undef, '^\/\S+$');

&nginx_logformat_parse("log_format", $http);

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("logs");
&redirect("");

