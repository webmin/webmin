#!/usr/local/bin/perl
# restart.cgi
# Stop and start the print scheduler

require './lpadmin-lib.pl';
&ReadParse();
$access{'stop'} == 2 || &error($text{'restart_ecannot'});
&error_setup($text{'restart_err'});
&stop_sched(&sched_running());
sleep(2);
&start_sched();
&webmin_log("restart");
&redirect("");

