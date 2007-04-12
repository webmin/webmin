#!/usr/local/bin/perl
# delete_env.cgi
# Delete an environment variable for some user

require './cron-lib.pl';
&ReadParse();
@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
&lock_file($job->{'file'});
&can_edit_user(\%access, $job->{'user'}) ||
	&error($text{'edit_ecannot'});
&delete_cron_job($job);
&unlock_file($job->{'file'});
&webmin_log("delete", "env", $job->{'user'}, $job);
&redirect("");

