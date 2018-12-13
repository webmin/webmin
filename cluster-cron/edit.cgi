#!/usr/local/bin/perl
# edit.cgi
# Edit an existing or new cluster cron job

require './cluster-cron-lib.pl';
&ReadParse();

if (!$in{'new'}) {
	@jobs = &list_cluster_jobs();
	($job) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
	$job || &error($text{'edit_emissing'});
	&ui_print_header(undef, $text{'edit_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'create_title'}, "");
	$job = { 'mins' => '*',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		 'active' => 1 };
	}

print &ui_form_start("save.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $in{'id'});
print &ui_table_start($cron::text{'edit_details'}, "width=100%", 4);

# Run as user
print &ui_table_row($cron::text{'edit_user'},
	&ui_user_textbox("user", $job->{'cluster_user'}));

# Cron job active?
print &ui_table_row($cron::text{'edit_active'},
	&ui_yesno_radio("active", $job->{'active'}));

# Run on servers
my @opts;
push(@opts, [ "ALL", $text{'edit_all'} ]);
push(@opts, [ "*", $text{'edit_this'} ]);
foreach $s (grep { $_->{'user'} }
		 sort { $a->{'host'} cmp $b->{'host'} }
		      &servers::list_servers()) {
	push(@opts, [ $s->{'host'},
		      $s->{'host'}.($s->{'desc'} ? " ($s->{'desc'})" : "") ]);
	}
foreach $g (sort { $a->{'name'} cmp $b->{'name'} }
		 &servers::list_all_groups()) {
	$gn = "group_".$g->{'name'};
	push(@opts, [ $gn, &text('edit_group', $g->{'name'}) ]);
	}
print &ui_table_row($text{'edit_servers'},
	&ui_select("server", [ split(/ /, $job->{'cluster_server'}) ],
		   \@opts, 8, 1), 3);

# Command to run
print &ui_table_row($cron::text{'edit_command'},
	&ui_textbox("cmd", $job->{'cluster_command'}, 70), 3);

if ($cron::config{'cron_input'}) {
	# Input to command
	@lines = split(/%/ , $job->{'cluster_input'});
	print &ui_table_row($cron::text{'edit_input'},
		&ui_textarea("input", join("\n" , @lines), 3, 70), 3);
	}

print &ui_table_end();

print &ui_table_start($cron::text{'edit_when'}, "width=100%", 2);
print &cron::get_times_input($job);
print &ui_table_end();

if (!$in{'new'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'exec', $cron::text{'edit_run'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

