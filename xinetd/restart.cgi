#!/usr/local/bin/perl
# restart.cgi
# Restart the running xinetd

require './xinetd-lib.pl';
&ReadParse();
&error_setup($text{'restart_err'});
$pid = &is_xinetd_running();
$pid || &error(&text('restart_epid'));
&kill_logged('USR2', $pid) ||
	&error(&text('restart_ekill', $pid, $!));
&webmin_log("apply");
&redirect("");

