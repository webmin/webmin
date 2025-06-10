#!/usr/local/bin/perl
# delete_cron.cgi
# Delete a cron job for some user

require './cron-lib.pl';
&ReadParse();
@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
&lock_file($job->{'file'});
$access{'delete'} && &can_edit_user(\%access, $job->{'user'}) ||
	&error($text{'edit_ecannot'});
&delete_cron_job($job);
&unlock_file($job->{'file'});
&webmin_log("delete", "cron", $job->{'user'}, $job);
&redirect("");

