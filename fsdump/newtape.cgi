#!/usr/local/bin/perl
# newtape.cgi
# Indicate that a new tape is loaded for a backup job

require './fsdump-lib.pl';
&ReadParse();
&error_setup($text{'newtape_err'});

&foreign_require("proc", "proc-lib.pl");
@procs = &proc::list_processes();
@running = &running_dumps(\@procs);

($job) = grep { $_->{'id'} eq $in{'id'} &&
		$_->{'pid'} == $in{'pid'} } @running;
$job || &error($text{'newtape_egone'});
&can_edit_dir($job) || &error($text{'newtape_ecannot'});
$job->{'status'}->{'status'} eq 'tape' || &error($text{'newtape_estatus'});

kill('HUP', $job->{'status'}->{'tapepid'});
&redirect("");

