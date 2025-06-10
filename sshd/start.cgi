#!/usr/local/bin/perl
# start.cgi
# Start the ssh daemon

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'start_err'});
$err = &start_sshd();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

