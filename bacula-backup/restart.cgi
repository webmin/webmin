#!/usr/local/bin/perl
# Re-start Bacula

require './bacula-backup-lib.pl';
&error_setup($text{'restart_err'});
$err = &restart_bacula();
&error($err) if ($err);
&webmin_log("restart");
&redirect("");


