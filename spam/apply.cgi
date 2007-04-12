#!/usr/local/bin/perl
# apply.cgi
# Send a HUP signal to spamassassin-related processes

require './spam-lib.pl';
&error_setup($text{'apply_err'});
$err = &restart_spamd();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

