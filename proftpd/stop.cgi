#!/usr/local/bin/perl
# Stop the ProFTPD server process

require './proftpd-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_proftpd();
&error($err) if ($err);
&webmin_log("stop");
&redirect($in{'redir'});

