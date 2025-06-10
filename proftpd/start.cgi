#!/usr/local/bin/perl
# start.cgi
# Start the ProFTPD server process

require './proftpd-lib.pl';
&error_setup($text{'start_err'});
$err = &start_proftpd();
&error($err) if ($err);
&webmin_log("start");
&redirect($in{'redir'});

