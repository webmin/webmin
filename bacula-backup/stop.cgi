#!/usr/local/bin/perl
# Stop Bacula

require './bacula-backup-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_bacula();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");


