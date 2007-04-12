#!/usr/local/bin/perl
# stop_portsentry.cgi
# Stop portsentry daemon

require './sentry-lib.pl';
&error_setup($text{'portsentry_stoperr'});

$err = &stop_portsentry();
&error($err) if ($err);
&webmin_log("stop", "portsentry");

&redirect("edit_portsentry.cgi");

