#!/usr/local/bin/perl
# apply.cgi
# Apply config file changes with a HUP signal

require './sshd-lib.pl';
&ReadParse();
$err = &restart_sshd();
&error($err) if ($err);
sleep(2);	# wait to come back up
&webmin_log("apply");
&redirect("");

