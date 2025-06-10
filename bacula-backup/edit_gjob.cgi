#!/usr/local/bin/perl
# Show the details of one backup job

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@jobs = &find("JobDefs", $conf);
@clients = map { $n=&find_value("Name", $_->{'members'}); }
	        grep { ($g, $c) = &is_oc_object($_); $g && !$c }
		   &find("Client", $conf);
@filesets = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("FileSet", $conf);
@schedules = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Schedule", $conf);
@storages = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Storage", $conf);
@pools = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Pool", $conf);
@messages = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Messages", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'gjob_title1'}, "");
	$mems = [ { 'name' => 'Type',
		    'value' => 'Backup' },
		  { 'name' => 'Level',
		    'value' => 'Incremental' },
		  { 'name' => 'Client',
		    'value' => $clients[0] },
		  { 'name' => 'FileSet',
		    'value' => $filesets[0] },
		  { 'name' => 'Schedule',
		    'value' => $schedules[0] },
		  { 'name' => 'Storage',
		    'value' => $storages[0] },
		  { 'name' => 'Messages',
		    'value' => $messages[0] },
		  { 'name' => 'Pool',
		    'value' => $pools[0] },
		];
	$job = { 'name' => 'Job',
		 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'gjob_title2'}, "");
	$job = &find_by("Name", "ocjob_".$in{'name'}, \@jobs);
	$job || &error($text{'job_egone'});
	$mems = $job->{'members'};
	}

# Show details
print &ui_form_start("save_gjob.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'gjob_header'}, "width=100%", 4);

# Job name
print &ui_table_row($text{'job_name'},
		    &ui_textbox("name", $in{'name'}, 40), 3);

# Job type
$type = &find_value("Type", $mems);
print &ui_table_row($text{'job_type'},
	&ui_select("type", $type,
		[ [ "Backup" ], [ "Restore" ], [ "Verify" ], [ "Admin" ] ],
		1, 0, 1));

# Backup level
$level = &find_value("Level", $mems);
print &ui_table_row($text{'job_level'},
	&ui_select("level", $level,
		[ map { [ $_ ] } @backup_levels ],
		1, 0, 1));

# Client being backed up
$client = &find_value("Client", $mems);
print &ui_table_row($text{'gjob_client'},
	&ui_select("client", $client,
		[ map { [ $_, &is_oc_object($_) ] } @clients ], 1, 0, 1));

# Files to be backed up
$fileset = &find_value("FileSet", $mems);
print &ui_table_row($text{'job_fileset'},
	&ui_select("fileset", $fileset,
		[ map { [ $_ ] } @filesets ], 1, 0, 1));

# Backup schedule
$schedule = &find_value("Schedule", $mems);
print &ui_table_row($text{'job_schedule'},
	&ui_select("schedule", $schedule,
		[ [ "", "&lt;$text{'default'}&gt;" ],
		  map { [ $_ ] } @schedules ], 1, 0, 1));

# Storage device
$storage = &find_value("Storage", $mems);
print &ui_table_row($text{'job_storage'},
	&ui_select("storage", $storage,
		[ map { [ $_ ] } @storages ], 1, 0, 1));

# Backup pool
$pool = &find_value("Pool", $mems);
print &ui_table_row($text{'job_pool'},
	&ui_select("pool", $pool,
		[ map { [ $_ ] } @pools ], 1, 0, 1));

# Backup messages
$messages = &find_value("Messages", $mems);
print &ui_table_row($text{'job_messages'},
	&ui_select("messages", $messages,
		[ map { [ $_ ] } @messages ], 1, 0, 1));

# Priority level
$prority = &find_value("Priority", $mems);
print &ui_table_row($text{'job_prority'},
	&ui_opt_textbox("priority", $priority, 4, $text{'default'}));

# Before and after commands
print &ui_table_hr();

$before = &find_value("Run Before Job", $mems);
print &ui_table_row($text{'job_before'},
	&ui_opt_textbox("before", $before, 60, $text{'default'}), 3);
$after = &find_value("Run After Job", $mems);
print &ui_table_row($text{'job_after'},
	&ui_opt_textbox("after", $after, 60, $text{'default'}), 3);

$cbefore = &find_value("Client Run Before Job", $mems);
print &ui_table_row($text{'job_cbefore'},
	&ui_opt_textbox("cbefore", $cbefore, 60, $text{'default'}), 3);
$cafter = &find_value("Client Run After Job", $mems);
print &ui_table_row($text{'job_cafter'},
	&ui_opt_textbox("cafter", $cafter, 60, $text{'default'}), 3);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "run", $text{'job_run'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_gjobs.cgi", $text{'jobs_return'});

