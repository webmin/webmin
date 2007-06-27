#!/usr/local/bin/perl
# Start Bacula

require './bacula-backup-lib.pl';
&error_setup($text{'start_err'});
$err = &start_bacula();
&error($err) if ($err);
&webmin_log("start");
&redirect("");


