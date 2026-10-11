#!/usr/local/bin/perl
# Delete multiple Cron jobs at once

require './cron-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@jobs = &list_cron_jobs();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

if ($in{'delete'}) {
	# Validate all selected jobs before changing any of them
	@selected = ( );
	foreach $d (sort { $b <=> $a } @d) {
		($job) = grep { $_->{'index'} eq $d } @jobs;
		$job || next;
		!$job->{'name'} || $access{'env'} ||
			&error($text{'env_ecannot'});
		$access{'delete'} && &can_edit_user(\%access, $job->{'user'}) ||
			&error($text{'edit_ecannot'});
		push(@selected, $job);
		}
	# Delete selected jobs
	foreach $job (@selected) {
		&lock_file($job->{'file'});
		&delete_cron_job($job);
		@jobs = grep { $_ ne $job } @jobs;
		}
	&unlock_all_files();
	&webmin_log("delete", "crons", scalar(@d));
	}
elsif ($in{'disable'} || $in{'enable'}) {
	# Validate all selected jobs before changing any of them
	@selected = ( );
	foreach $d (@d) {
		($job) = grep { $_->{'index'} eq $d } @jobs;
		$job || next;
		!$job->{'name'} || $access{'env'} ||
			&error($text{'env_ecannot'});
		&can_edit_user(\%access, $job->{'user'}) ||
                        &error($text{'edit_ecannot'});
		push(@selected, $job);
		}
	# Enable or disable selected jobs
	foreach $job (@selected) {
		&lock_file($job->{'file'});
		$job->{'active'} = $in{'disable'} ? 0 : 1;
		&change_cron_job($job);
		@jobs = grep { $_ ne $job } @jobs;
		}
	&unlock_all_files();
	&webmin_log($in{'disable'} ? "disable" : "enable", "crons", scalar(@d));
	}
&redirect("");

