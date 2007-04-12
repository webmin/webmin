#!/usr/local/bin/perl
# kill.cgi
# Terminate a running backup job

require './fsdump-lib.pl';
&ReadParse();
&error_setup($text{'kill_err'});

&foreign_require("proc", "proc-lib.pl");
@procs = &proc::list_processes();
@running = &running_dumps(\@procs);

($job) = grep { $_->{'id'} == $in{'id'} &&
		$_->{'pid'} == $in{'pid'} } @running;
$job || &error($text{'kill_egone'});
&can_edit_dir($job) || &error($text{'kill_ecannot'});

kill('TERM', $job->{'pid'});
&redirect("");

