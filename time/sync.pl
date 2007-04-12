#!/usr/local/bin/perl
# sync.pl
# Sync with a time server, from cron

$no_acl_check++;
require './time-lib.pl';

$err = &sync_time($config{'timeserver'}, $config{'timeserver_hardware'});
if ($err) {
	print STDERR $err;
	exit(1);
	}
exit(0);
