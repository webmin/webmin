#!/usr/local/bin/perl
# Delete multiple Cron jobs at once

require './cron-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@jobs = &list_cron_jobs();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

if ($in{'delete'}) {
	# Delete selected jobs
	foreach $d (sort { $b <=> $a } @d) {
		$job = $jobs[$d];
		&lock_file($job->{'file'});
		$access{'delete'} && &can_edit_user(\%access, $job->{'user'}) ||
			&error($text{'edit_ecannot'});
		&delete_cron_job($job);
		}
	&unlock_all_files();
	&webmin_log("delete", "crons", scalar(@d));
	}
elsif ($in{'disable'} || $in{'enable'}) {
	# Disable selected
	foreach $d (@d) {
		$job = $jobs[$d];
		&lock_file($job->{'file'});
		&can_edit_user(\%access, $job->{'user'}) ||
                        &error($text{'edit_ecannot'});
		$job->{'active'} = $in{'disable'} ? 0 : 1;
		&change_cron_job($job);
		}
	&unlock_all_files();
	&webmin_log($in{'disable'} ? "disable" : "enable", "crons", scalar(@d));
	}
&redirect("");

