#!/usr/local/bin/perl
# Delete multiple cluster copies

require './cluster-copy-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

foreach $d (@d) {
	$copy = &get_copy($d);
	if ($copy) {
		$job = &find_cron_job($copy);
		&delete_copy($copy);
		if ($job) {
			&lock_file(&cron::cron_file($job));
			&cron::delete_cron_job($job);
			&unlock_file(&cron::cron_file($job));
			}
		}
	}
&webmin_log("deletes", undef, scalar(@d));
&redirect("");

