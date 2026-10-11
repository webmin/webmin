#!/usr/local/bin/perl
# delete_env.cgi
# Delete an environment variable for some user

require './cron-lib.pl';
&ReadParse();
$access{'env'} || &error($text{'env_ecannot'});
@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
$job && $job->{'name'} || &error($text{'env_egone'});
$access{'delete'} && &can_edit_user(\%access, $job->{'user'}) ||
	&error($text{'edit_ecannot'});
&lock_file($job->{'file'});
&delete_cron_job($job);
&unlock_file($job->{'file'});
&webmin_log("delete", "env", $job->{'user'}, $job);
&redirect("");

