#!/usr/local/bin/perl
# move.cgi
# Move a cron job up or down

require './cron-lib.pl';
&error_setup($text{'move_err'});
&ReadParse();

@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
if ($in{'up'}) {
	$swap = $jobs[$in{'idx'}-1];
	}
else {
	$swap = $jobs[$in{'idx'}+1];
	}
$access{'move'} && &can_edit_user(\%access, $job->{'user'}) ||
	&error(&text('save_ecannot', $job->{'user'}));
&can_edit_user(\%access, $swap->{'user'}) ||
	&error(&text('save_ecannot', $swap->{'user'}));
$job->{'file'} eq $swap->{'file'} &&
  ($job->{'type'} == 0 || $job->{'type'} == 3) &&
  ($swap->{'type'} == 0 || $swap->{'type'} == 3) || &error($text{'move_etype'});
&lock_file($job->{'file'});
&swap_cron_jobs($job, $swap);
&unlock_file($job->{'file'});
&webmin_log("move", "cron", $job->{'user'});
&redirect("");

