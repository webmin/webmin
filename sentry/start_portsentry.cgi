#!/usr/local/bin/perl
# start_portsentry.cgi
# Start the portsentry daemon

require './sentry-lib.pl';
&error_setup($text{'portsentry_starterr'});

$cmd = &portsentry_start_cmd();
$out = &backquote_logged("$cmd 2>&1 </dev/null");
&error("<tt>$out</tt>") if ($out =~ /failed|error/i);
&webmin_log("start", "portsentry");

&redirect("edit_portsentry.cgi");

