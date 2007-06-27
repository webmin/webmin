#!/usr/local/bin/perl
# Delete multiple schedules

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@schedules = &find("Schedule", $conf);

&error_setup($text{'schedules_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$schedule = &find_by("Name", $d, \@schedules);
	if ($schedule) {
		$child = &find_dependency("Schedule", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('schedule_echild', $child));
		&save_directive($conf, $parent, $schedule, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "schedules", scalar(@d));
&redirect("list_schedules.cgi");

