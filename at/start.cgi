#!/usr/local/bin/perl
# Start the atd server

require './at-lib.pl';
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});
&foreign_require("init");
my $init = &get_init_name();
my ($ok, $err) = &init::start_action($init);
&error($err) if (!$ok);
&webmin_log("start");
&redirect("");


