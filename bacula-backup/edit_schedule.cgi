#!/usr/local/bin/perl
# Show the details of one schedule

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@schedules = &find("Schedule", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'schedule_title1'}, "");
	$mems = [ ];
	$schedule = { };
	}
else {
	&ui_print_header(undef, $text{'schedule_title2'}, "");
	$schedule = &find_by("Name", $in{'name'}, \@schedules);
	$schedule || &error($text{'schedule_egone'});
	$mems = $schedule->{'members'};
	}

# Show details
print &ui_form_start("save_schedule.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'schedule_header'}, "width=100%", 4);

# Schedule
print &ui_table_row($text{'schedule_name'},
	    &ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Run files
@runs = &find_value("Run", $schedule->{'members'});
$rtable = &ui_columns_start([ $text{'schedule_level'},
			      $text{'schedule_times'} ], "width=100%");
$i = 0;
foreach $r (@runs, undef, undef, undef) {
	($level, $times) = split(/\s+/, $r, 2);
	$level =~ s/^Level\s*=\s*//;
	$sched = &parse_schedule($times);
	$rtable .= &ui_columns_row([
		&ui_select("level_$i", $level,
			   [ [ "", "&nbsp;" ], [ "Full" ],
			     [ "Incremental" ], [ "Differential" ] ],
			   1, 0, 1),
		&ui_textbox("times_$i", $times,
			    $sched || !$r ? "40 readonly" : 40)." ".
		&schedule_chooser_button("times_$i") ]);
	$i++;
	}
$rtable .= &ui_columns_end();
print &ui_table_row($text{'schedule_runs'}, $rtable);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_schedules.cgi", $text{'schedules_return'});

