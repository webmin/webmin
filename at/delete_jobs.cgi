#!/usr/local/bin/perl
# Delete multiple at jobs

require './at-lib.pl';
&ReadParse();
&error_setup($text{'deletes_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'deletes_enone'});

# Delete each one
@jobs = &list_atjobs();
%access = &get_module_acl();
foreach $d (@d) {
	($job) = grep { $_->{'id'} eq $d } @jobs;
	$job || &error($text{'delete_egone'});
	&can_edit_user(\%access, $job->{'user'}) ||
		&error($text{'edit_ecannot'});
	&delete_atjob($job->{'id'});
	}
&webmin_log("delete", "jobs", scalar(@d));
&redirect("");

