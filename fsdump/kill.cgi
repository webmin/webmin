#!/usr/local/bin/perl
# kill.cgi
# Terminate a running backup job

require './fsdump-lib.pl';
&ReadParse();
&error_setup($text{'kill_err'});

&foreign_require("proc", "proc-lib.pl");
@procs = &proc::list_processes();
@running = &running_dumps(\@procs);

# Find the job
($job) = grep { $_->{'id'} eq $in{'id'} &&
		$_->{'pid'} == $in{'pid'} } @running;
$job || &error($text{'kill_egone'});
&can_edit_dir($job) || &error($text{'kill_ecannot'});

# Find all sub-processes
@killprocs = ( $job->{'pid'}, &find_subprocesses($job->{'pid'}) );
&kill_logged('TERM', @killprocs);
sleep(1);
&kill_logged('KILL', @killprocs);
&webmin_log("kill", undef, $job->{'id'}, $job);
&redirect("");

sub find_subprocesses
{
local ($pid) = @_;
local @rv;
foreach my $p (@procs) {
	if ($p->{'ppid'} && $p->{'ppid'} eq $pid) {
		push(@rv, $p->{'pid'}, &find_subprocesses($p->{'pid'}));
		}
	}
return @rv;
}

