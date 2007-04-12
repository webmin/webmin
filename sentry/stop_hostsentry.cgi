#!/usr/local/bin/perl
# stop_hostsentry.cgi
# Stop hostsentry daemon

require './sentry-lib.pl';
&error_setup($text{'hostsentry_stoperr'});

$err = &stop_hostsentry();
&error($err) if ($err);
&webmin_log("stop", "hostsentry");

&redirect("edit_hostsentry.cgi");

