#!/usr/local/bin/perl
# Re-start the webserver

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
&error_setup($text{'restart_err'});

my $test = &test_config();
$test && &error(&text('restart_etest',
		"<tt>".&html_escape($test)."</tt>"));

my $err = &apply_nginx();
$err && &error("<tt>".&html_escape($err)."</tt>");
&webmin_log("restart");
&redirect($in{'redir'} || "");
