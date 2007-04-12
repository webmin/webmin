#!/usr/local/bin/perl
# delete.cgi
# Delete an existing cluster cron job

require './cluster-cron-lib.pl';
&ReadParse();
@jobs = &list_cluster_jobs();
($job) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
&delete_cluster_job($job);
&webmin_log("delete", "cron", $job->{'cluster_user'}, $job);
&redirect("");

