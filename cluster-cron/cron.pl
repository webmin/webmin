#!/usr/local/bin/perl
# cron.pl
# Run a command on multiple servers at once

$no_acl_check++;
require './cluster-cron-lib.pl';

@jobs = &list_cluster_jobs();
($job) = grep { $_->{'cluster_id'} eq $ARGV[0] } @jobs;
$job || die "Job ID $ARGV[0] does not exist!";
$ENV{'SERVER_ROOT'} = $root_directory;	# hack to make 'this server' work
&run_cluster_job($job, \&callback);

# callback(error, &server, message)
sub callback
{
local $d = $_[1]->{'desc'} || $_[1]->{'host'};
if (!$_[0]) {
	# Failed - show error
	print "Failed to run on $d : $_[2]\n\n";
	}
else {
	# Show output if any
	if ($_[2]) {
		print "Output from $d ..\n";
		print $_[2];
		print "\n";
		}
	}
}

