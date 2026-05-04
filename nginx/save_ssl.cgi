#!/usr/local/bin/perl
# Save server block SSL options

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

&nginx_opt_parse("ssl_certificate", $server, undef, undef, \&valid_cert_file);

&nginx_opt_parse("ssl_certificate_key", $server, undef, undef,\&valid_key_file);

if ($in{'ssl'} && $in{"ssl_certificate_def"}) {
	&error($text{'ssl_ecert'});
	}
if ($in{'ssl'} && $in{"ssl_certificate_key_def"}) {
	&error($text{'ssl_ekey'});
	}

&nginx_opt_parse("ssl_ciphers", $server, undef, '^\S+$');

&nginx_multi_parse("ssl_protocols", $server);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("ssl", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

