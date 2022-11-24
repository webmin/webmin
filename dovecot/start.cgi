#!/usr/local/bin/perl
# Start the dovecot server

require './dovecot-lib.pl';
&error_setup($text{'start_err'});
$err = &start_dovecot();
&error($err) if ($err);
&webmin_log("start");
&redirect("");


