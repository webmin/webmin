#!/usr/local/bin/perl
# Stop the ssh daemon

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'stop_err'});
$err = &stop_sshd();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

