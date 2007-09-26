#!/usr/local/bin/perl
# Create, update or delete a backup schedule

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@schedules = &find("Schedule", $conf);

if (!$in{'new'}) {
	$schedule = &find_by("Name", $in{'old'}, \@schedules);
        $schedule || &error($text{'schedule_egone'});
	}
else {
	$schedule = { 'type' => 1,
		     'name' => 'Schedule',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $schedule->{'members'});
	$child = &find_dependency("Schedule", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('schedule_echild', $child));
	&save_directive($conf, $parent, $schedule, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'schedule_err'});
	$in{'name'} =~ /\S/ || &error($text{'schedule_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@schedules);
		$clash && &error($text{'schedule_eclash'});
		}
	&save_directive($conf, $schedule, "Name", $in{'name'}, 1);

	# Parse and save run times
	for($i=0; defined($level = $in{"level_$i"}); $i++) {
		next if (!$level);
		$times = $in{"times_$i"};
		$times =~ /\S/ || &error(&text('schedule_etimes', $i+1));
		push(@runs, "Level=$level ".
			    ($in{"pool_$i"} ? "Pool=".$in{"pool_$i"}." " : "").
			    $times);
		}
	&save_directives($conf, $schedule, "Run", \@runs, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $schedule, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "schedule", $in{'old'} || $in{'name'});
&redirect("list_schedules.cgi");

