#!/usr/local/bin/perl
# Delete multiple jobs

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@jobs = ( &find("JobDefs", $conf), &find("Job", $conf) );

&error_setup($text{'jobs_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$job = &find_by("Name", $d, \@jobs);
	if ($job) {
		$child = &find_dependency("JobDefs", $d, [ "Job" ], $conf);
		$child && &error(&text('job_echild', $child));
		&save_directive($conf, $parent, $job, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "jobs", scalar(@d));
&redirect("list_jobs.cgi");

