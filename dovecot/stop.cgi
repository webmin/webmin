#!/usr/local/bin/perl
# Stop the dovecot server

require './dovecot-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_dovecot();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");


