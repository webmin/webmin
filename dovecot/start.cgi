#!/usr/local/bin/perl
# Start the dovecot server

require './dovecot-lib.pl';
&error_setup($text{'start_err'});
$conf = &get_config();
@protos = split(/\s+/, &find_value("protocols", $conf));
@protos || &error($text{'start_eprotos'});
$err = &start_dovecot();
&error($err) if ($err);
&webmin_log("start");
&redirect("");


