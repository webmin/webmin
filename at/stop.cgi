#!/usr/local/bin/perl
# Stop the atd server

require './at-lib.pl';
&error_setup($text{'stop_err'});
$access{'stop'} || &error($text{'stop_ecannot'});
&foreign_require("init");
my $init = &get_init_name();
my ($ok, $err) = &init::stop_action($init);
&error($err) if (!$ok);
&webmin_log("stop");
&redirect("");


