#!/usr/local/bin/perl
# Delete multiple cluster cron jobs

require './cluster-cron-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

@jobs = &list_cluster_jobs();
foreach $d (@d) {
	($job) = grep { $_->{'cluster_id'} eq $d } @jobs;
	if ($job) {
		&delete_cluster_job($job);
		}
	}
&webmin_log("deletes", "cron", scalar(@d));
&redirect("");

