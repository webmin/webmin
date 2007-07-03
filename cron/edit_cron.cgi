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

print "<form action=save_cron.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

if (&supports_users()) {
	# Allow selection of user
	print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
	if ($access{'mode'} == 1) {
		print "<td><select name=user>\n";
		foreach $u (split(/\s+/, $access{'users'})) {
			printf "<option %s>$u\n",
				$job->{'user'} eq $u ? "selected" : "";
			}
		print "</select></td>\n";
		}
	elsif ($access{'mode'} == 3) {
		print "<td><tt>$remote_user</tt></td>\n";
		print "<input type=hidden name=user value='$remote_user'>\n";
		}
	else {
		print "<td><input name=user size=8 value=\"$job->{'user'}\"> ",
			&user_chooser_button("user", 0),"</td>\n";
		}
	}
else {
	# No such thing as users!
	print "<tr>\n";
	}

print "<td> <b>$text{'edit_active'}</b></td>\n";
printf "<td><input type=radio name=active value=1 %s> $text{'yes'}\n",
	$job->{'active'} ? "checked" : "";
printf "<input type=radio name=active value=0 %s> $text{'no'}</td> </tr>\n",
	$job->{'active'} ? "" : "checked";

&convert_comment($job);
$rpd = &is_run_parts($job->{'command'});
if ($rpd) {
	# run-parts command.. just show scripts that will be run
	print "<tr> <td valign=top><b>$text{'edit_commands'}</b></td>\n";
	print "<td><tt>",join("<br>",&expand_run_parts($rpd)),
	      "</tt></td> </tr>\n";
	print "<input type=hidden name=cmd value='$job->{'command'}'>\n";
	}
elsif (!$access{'command'}) {
	# Just show command, which cannot be edited
	print "<tr> <td><b>$text{'edit_command'}</b></td>\n";
	print "<td colspan=3><tt>$job->{'command'}</tt></td> </tr>\n";
	}
else {
	# Normal cron job.. can edit command
	&convert_range($job);
	$rangeable = 1;
	($command, $input) = &extract_input($job->{'command'});
	@lines = split(/%/, $input);
	print "<tr> <td><b>$text{'edit_command'}</b></td>\n";
	print "<td colspan=3><input name=cmd size=60 ",
	      "value='",&html_escape($command),"'></td> </tr>\n";

	if ($config{'cron_input'}) {
		print "<tr> <td valign=top><b>$text{'edit_input'}</b></td>\n";
		print "<td colspan=3><textarea name=input rows=3 cols=50>",
		      join("\n" , @lines),"</textarea></td> </tr>\n";
		}
	}

# Show comment
print "<tr> <td><b>$text{'edit_comment'}</b></td>\n";
print "<td colspan=3>",&ui_textbox("comment", $job->{'comment'}, 60),
      "</td> </tr>\n";

print "</table></td></tr></table><p>\n";

# Show times and days to run
print "<table border width=100%>\n";
print "<tr $tb> <td colspan=5><b>$text{'edit_when'}</b></td> </tr>\n";
&show_times_input($job);
print "</table>\n";

if ($rangeable) {
	# Show date range to run
	print "<p><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_range'}</b></td> </tr>\n";
	print "<tr $cb><td>";
	&show_range_input($job);
	print "</td></tr></table>\n";
	}

if (!$in{'new'}) {
	print "<table width=100%>\n";

	# Save button
	print "<tr> <td align=left width=25%><input type=submit value=\"$text{'save'}\"></td>\n";

	# Run button
	if (!$rpd) {
		print "</form><form action=\"exec_cron.cgi\">\n";
		print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
		print "<td align=center width=25%>",
		      "<input type=submit value=\"$text{'edit_run'}\"></td>\n";
		}

	# Clone button
	print "</form><form action=\"edit_cron.cgi\">\n";
	print "<input type=hidden name=clone value=\"$in{'idx'}\">\n";
	print "<input type=hidden name=new value=\"1\">\n";
	print "<td align=right width=25%><input type=submit value=\"$text{'edit_clone'}\"></td>\n";

	# Delete button
	if ($access{'delete'}) {
		print "</form><form action=\"delete_cron.cgi\">\n";
		print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
		print "<td align=right width=25%><input type=submit value=\"$text{'delete'}\"></td> </tr>\n";
		}
	else {
		print "<td align=right width=25%></td>\n";
		}
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

