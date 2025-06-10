#!/usr/local/bin/perl
# Apply the Bacula configuration

require './bacula-backup-lib.pl';
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("restart");
&redirect("");


