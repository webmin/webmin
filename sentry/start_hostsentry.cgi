#!/usr/local/bin/perl
# start_hostsentry.cgi
# Start the hostsentry daemon

require './sentry-lib.pl';
&error_setup($text{'hostsentry_starterr'});

$err = &start_hostsentry();
&error($err) if ($err);
&webmin_log("start", "hostsentry");

&redirect("edit_hostsentry.cgi");

