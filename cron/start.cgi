#!/usr/local/bin/perl
# Start crond

require './cron-lib.pl';
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});
&foreign_require("init");
my $init = $config{'init_name'};
my ($ok, $err) = &init::start_action($init);
&error($err) if (!$ok);
&webmin_log("start");
&redirect("");


