#!/usr/local/bin/perl
# edit_cron.cgi
# Edit an existing or new cron job

require './cron-lib.pl';
&ReadParse();
@jobs = &list_cron_jobs();

if (!$in{'new'}) {
	$job = $jobs[$in{'idx'}];
	&can_edit_user(\%access, $job->{'user'}) ||
		&error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'create_title'}, "");
	if (defined($in{'clone'})) {
		# Default to clone source
		$clone = $jobs[$in{'clone'}];
		$job = { %$clone };
		}
	elsif ($config{'vixie_cron'}) {
		# Default to hourly, using @ format
		$job = { 'special' => 'hourly',
			 'active' => 1 };
		}
	else {
		# Default to hourly, using standard notation
		$job = { 'mins' => '0',
			 'hours' => '*',
			 'days' => '*',
			 'months' => '*',
			 'weekdays' => '*',
			 'active' => 1 };
		}
	}

print &ui_form_start("save_cron.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("search", $in{'search'});
print &ui_table_start($text{'edit_details'}, "width=100%", 2);

if (&supports_users()) {
	# Allow selection of user
	if ($access{'mode'} == 1) {
		$usel = &ui_select("user", $job->{'user'},
				   [ split(/\s+/, $access{'users'}) ]);
		}
	elsif ($access{'mode'} == 3) {
		$usel = "<tt>$remote_user</tt>";
		print &ui_hidden("user", $remote_user);
		}
	else {
		$usel = &ui_user_textbox("user", $job->{'user'});
		}
	print &ui_table_row($text{'edit_user'}, $usel);
	}

# Is job active?
print &ui_table_row($text{'edit_active'},
	&ui_yesno_radio("active", $job->{'active'} ? 1 : 0));

&convert_comment($job);
$rpd = &is_run_parts($job->{'command'});
if ($rpd) {
	# run-parts command.. just show scripts that will be run
	print &ui_table_row($text{'edit_commands'},
		"<tt>".join("<br>",&expand_run_parts($rpd))."</tt>".
		&ui_hidden("cmd", $job->{'command'}));
	}
elsif (!$access{'command'}) {
	# Just show command, which cannot be edited
	print &ui_table_row($text{'edit_commands'},
		"<tt>".&html_escape($job->{'command'})."</tt>");
	}
else {
	# Normal cron job.. can edit command
	&convert_range($job);
	$rangeable = 1;
	($command, $input) = &extract_input($job->{'command'});
	$command =~ s/\\%/%/g;
	$input =~ s/\\%/%/g;
	@lines = split(/%/, $input);
	print &ui_table_row($text{'edit_command'},
		&ui_textbox("cmd", $command, 60));

	if ($config{'cron_input'}) {
		print &ui_table_row($text{'edit_input'},
			&ui_textarea("input", join("\n" , @lines), 3, 50));
		}
	}

# Show comment
print &ui_table_row($text{'edit_comment'},
	&ui_textbox("comment", $job->{'comment'}, 60));

print &ui_table_end();

# Show times and days to run
print &ui_table_start($text{'edit_when'}, "width=100%", 2);
print &get_times_input($job);
print &ui_table_end();

if ($rangeable) {
	# Show date range to run
	print &ui_table_start($text{'edit_range'}, "width=100%", 2);
	print &ui_table_row(undef,
		&capture_function_output(\&show_range_input, $job), 2);
	print &ui_table_end();
	}

if (!$in{'new'}) {
	# Save button
	print &ui_submit($text{'save'});
	print &ui_submit($text{'edit_saverun'}, 'saverun');
	print &ui_form_end();
	# Run button
	print "<table class='ui_table_end_submit_right'><tr>\n";
	if (!$rpd) {
		print "<td>";
		print &ui_form_start("exec_cron.cgi");
		print &ui_hidden("idx", $in{'idx'});
		print &ui_submit($text{'edit_run'});
		print &ui_form_end();
		print "</td>\n";
		}

	# Clone button
	print "<td>";
	print &ui_form_start("edit_cron.cgi");
	print &ui_hidden("clone", $in{'idx'});
	print &ui_hidden("new", 1);
	print &ui_submit($text{'edit_clone'});
	print &ui_form_end();
	print "</td>";

	# Delete button
	if ($access{'delete'}) {
		print "<td>";
		print &ui_form_start("delete_cron.cgi");
		print &ui_hidden("idx", $in{'idx'});
		print &ui_submit($text{'delete'});
		print &ui_form_end();
		print "</td>\n";
		}
	print "</tr></table>\n";
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?search=".&urlize($in{'search'}),
		 $text{'index_return'});

