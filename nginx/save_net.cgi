#!/usr/local/bin/perl
# Save networking-related options

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %access);
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
&error_setup($text{'net_err'});
&ReadParse();
$access{'global'} || &error($text{'index_eglobal'});

&nginx_onoff_parse("sendfile", $http);

&nginx_onoff_parse("gzip", $http);

&nginx_opt_parse("gzip_disable", $http, undef);

&nginx_onoff_parse("tcp_nopush", $http);

&nginx_onoff_parse("tcp_nodelay", $http);

&nginx_opt_parse("keepalive_timeout", $http, undef, '^\d+$');

&nginx_opt_parse("keepalive_requests", $http, undef, '^\d+$');

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("net");
&redirect("");

