#!/usr/local/bin/perl
# restart.cgi
# Restart the mon process

require './mon-lib.pl';
&error_setup($text{'restart_err'});
$err = &restart_mon();
&error($err) if ($err);
&redirect("");

