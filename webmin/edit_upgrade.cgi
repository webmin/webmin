#!/usr/local/bin/perl
# edit_upgrade.cgi
# Display a form for upgrading all of webmin from a tarfile

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'upgrade_title'}, "");

if (&shared_root_directory()) {
	&ui_print_endpage($text{'upgrade_eroot'});
	}

# what kind of install was this?
$mode = &get_install_type();

# was the install to a target directory?
if (open(DIR, "$config_directory/install-dir")) {
	chop($dir = <DIR>);
	close(DIR);
	}
if ($mode eq "solaris-pkg") {
	$skip_upgrade = $text{'upgrade_esolaris'};
	}
elsif ($mode eq "zip") {
	$skip_upgrade = $text{'upgrade_ezip'};
	}

# Show tabs
@tabs = map { [ $_, $text{'upgrade_tab'.$_}, "edit_upgrade.cgi?mode=$_" ] }
	    ( $skip_upgrade ? ( ) : ( "upgrade" ),
	      "grants", "update", "sched" );
print ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

if (!$skip_upgrade) {
	# Display upgrade form
	print ui_tabs_start_tab("mode", "upgrade");
	print $text{"upgrade_desc$mode"},"<p>";

	print ui_form_start("upgrade.cgi", "form-data");
	print ui_hidden("mode", $mode);
	print ui_hidden("dir", $dir);
	print ui_table_start($text{'upgrade_title'}, undef, 1);
	print "<tr $cb> <td nowrap>\n";
	print "<input type=radio name=source value=0> $text{'upgrade_local'}\n";
	print "<input name=file size=40>\n";
	print file_chooser_button("file", 0),"<br>\n";
	print "<input type=radio name=source value=1> $text{'upgrade_uploaded'}\n";
	print "<input name=upload type=file size=30><br>\n";
	print "<input type=radio name=source value=5> $text{'upgrade_url'}\n";
	print "<input name=url size=40><br>\n";
	if ($mode eq 'caldera') {
		print "<input type=radio name=source value=3 checked> $text{'upgrade_cup'}\n";
		}
	elsif ($mode eq "gentoo") {
		print "<input type=radio name=source value=4 checked> $text{'upgrade_emerge'}\n";
		}
	elsif ($mode ne "sun-pkg") {
		print "<input type=radio name=source value=2 checked> $text{'upgrade_ftp'}\n";
		}
	print "<p>\n";
	if (!$mode && !$dir) {
		# Checkbox to delete original directory
		print &ui_checkbox("delete", 1, $text{'upgrade_delete'},
				   $gconfig{'upgrade_delete'}),"<br>\n";
		}
	if ((!$mode || $mode eq "rpm") && &foreign_check("proc")) {
		# Checkbox to check signature
		($ec, $emsg) = &gnupg_setup();
		printf "<input type=checkbox name=sig value=1 %s> %s<br>\n",
			$ec ? "" : "checked", $text{'upgrade_sig'};
		}
	if (!$mode) {
		# Checkbox to not install missing modules
		printf "<input type=checkbox name=only value=1 %s> %s<br>\n",
			-r "$root_directory/minimal-install" ? "checked" : "",
			$text{'upgrade_only'};
		}
	printf "<input type=checkbox name=force value=1> %s<br>\n",
		$text{'upgrade_force'};
	if ($main::session_id) {
		# Checkbox to disconnect other sessions
		printf "<input type=checkbox name=disc value=1> %s<br>\n",
			$text{'upgrade_disc'};
		}
	print ui_table_end();
	print "<input type=submit value=\"$text{'upgrade_ok'}\">\n";
	print "</form>\n";
	print ui_tabs_end_tab();
	}

# Display new module grants form
print ui_tabs_start_tab("mode", "grants");
print "$text{'newmod_desc'}<p>\n";
print ui_form_start("save_newmod.cgi", "post");
print ui_table_start($text{'newmod_header'});

$newmod = &get_newmodule_users();
printf "<input type=radio name=newmod_def value=1 %s> %s<br>\n",
	$newmod ? "" : "checked", $text{'newmod_def'};
printf "<input type=radio name=newmod_def value=0 %s> %s\n",
	$newmod ? "checked" : "", $text{'newmod_users'};
printf "<input name=newmod size=30 value='%s'><br>\n",
	join(" ", @$newmod);

print ui_table_end();
print "<input type=submit value='$text{'save'}'></form>\n";
print ui_tabs_end_tab();

# Display module update form
print ui_tabs_start_tab("mode", "update");
print "$text{'update_desc1'}<p>\n";
print ui_form_start("update.cgi", "post");
print ui_table_start($text{'update_header1'});
print "<tr $cb> <td nowrap>\n";

printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s<br>\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
print "&nbsp;" x 4;
print &ui_textarea("other", join("\n", split(/\t+/, $config{'upsource'})),
		   2, 50),"<br>\n";

printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
	$config{'upshow'} ? "checked" : "", $text{'update_show'};
printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
	$config{'upmissing'} ? "checked" : "", $text{'update_missing'};
printf "<input type=checkbox name=third value=1 %s> %s<br>\n",
	$config{'upthird'} ? "checked" : "", $text{'update_third'};
printf "<input type=checkbox name=checksig value=1 %s> %s<br>\n",
        $config{'upchecksig'} ? 'checked' : '', $text{'update_checksig'};

print "<table>\n";
print "<tr> <td>$text{'update_user'}</td>\n";
print "<td>",&ui_textbox("upuser", $config{'upuser'}, 30),"</td> </tr>\n";
print "<tr> <td>$text{'update_pass'}</td>\n";
print "<td>",&ui_password("uppass", $config{'uppass'}, 30),"</td> </tr>\n";
print "</table>\n";

print ui_table_end();
print "<input type=submit value=\"$text{'update_ok'}\">\n";
print "</form>\n";
print ui_tabs_end_tab();

# Display scheduled update form
print ui_tabs_start_tab("mode", "sched");
print "$text{'update_desc2'}<p>\n";
print ui_form_start("update_sched.cgi", "post");
print ui_table_start($text{'update_header2'});
print "<tr $cb> <td nowrap>\n";
printf "<input type=checkbox name=enabled value=1 %s> %s<p>\n",
	$config{'update'} ? 'checked' : '', $text{'update_enabled'};
	
printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s<br>\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
print "&nbsp;" x 4;
print &ui_textarea("other", join("\n", split(/\t+/, $config{'upsource'})),
		   2, 50),"<br>\n";

if ($config{'cron_mode'} == 0) {
	$upmins = sprintf "%2.2d", $config{'upmins'};
	print &text('update_sched2',
		    "<input name=hour size=2 value='$config{'uphour'}'>",
		    "<input name=mins size=2 value='$upmins'>",
		    "<input name=days size=3 value='$config{'updays'}'>"),"<br>\n";
	}
else {
	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$job = &find_cron_job(\@jobs);
	$job ||= { 'mins' => 0,
		   'hours' => $config{'uphour'},
		   'days' => "*/$config{'updays'}",
		   'months' => '*',
		   'weekdays' => '*' };
	print "<br><table border=1>\n";
	&cron::show_times_input($job, 1);
	print "</table><br>\n";
	}

printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
      $config{'upshow'} ? 'checked' : '', $text{'update_show'};
printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
      $config{'upmissing'} ? 'checked' : '', $text{'update_missing'};
printf "<input type=checkbox name=third value=1 %s> %s<br>\n",
	$config{'upthird'} ? "checked" : "", $text{'update_third'};
printf "<input type=checkbox name=quiet value=1 %s> %s<br>\n",
      $config{'upquiet'} ? 'checked' : '', $text{'update_quiet'};
printf "<input type=checkbox name=checksig value=1 %s> %s<br>\n",
      $config{'upchecksig'} ? 'checked' : '', $text{'update_checksig'};

print "<table>\n";
print "<tr> <td>$text{'update_email'}</td>\n";
print "<td>",&ui_textbox("email", $config{'upemail'}, 30),"</td> </tr>\n";
print "<tr> <td>$text{'update_user'}</td>\n";
print "<td>",&ui_textbox("upuser", $config{'upuser'}, 30),"</td> </tr>\n";
print "<tr> <td>$text{'update_pass'}</td>\n";
print "<td>",&ui_password("uppass", $config{'uppass'}, 30),"</td> </tr>\n";
print "</table>\n";

print ui_table_end();
print "<input type=submit value=\"$text{'update_apply'}\">\n";
print "</form>\n";
print ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

