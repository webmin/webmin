#!/usr/local/bin/perl
# Delete a bunch of backups

require './fsdump-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Delete each one, and its cron job
foreach $d (@d) {
	$dump = &get_dump($d);
	$access{'edit'} && &can_edit_dir($dump) ||
		&error($text{'dump_ecannot2'});
	@jobs = &foreign_call("cron", "list_cron_jobs");
	($job) = grep { $_->{'command'} eq "$cron_cmd $dump->{'id'}" } @jobs;
	&delete_dump($dump);
	if ($job) {
		&lock_file($job->{'file'});
		&foreign_call("cron", "delete_cron_job", $job);
		&unlock_file($job->{'file'});
		}
	}

&webmin_log("delete", "dumps", scalar(@d));
&redirect("");

