#!/usr/local/bin/perl
# edit_upgrade.cgi
# Display a form for upgrading all of usermin from a tarfile

require './usermin-lib.pl';
$access{'upgrade'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'upgrade_title'}, "");

# what kind of install was this?
$mode = &get_install_type();

# was the install to a target directory?
if (open(DIR, "$config{'usermin_dir'}/install-dir")) {
	chop($dir = <DIR>);
	close(DIR);
	}

print $text{"upgrade_desc$mode"},"<p>";

print "<form action=upgrade.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=mode value='$mode'>\n";
print "<input type=hidden name=dir value='$dir'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'upgrade_title'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
print "<input type=radio name=source value=0> $text{'upgrade_local'}\n";
print "<input name=file size=40>\n";
print &file_chooser_button("file", 0),"<br>\n";
print "<input type=radio name=source value=1> $text{'upgrade_uploaded'}\n";
print "<input name=upload type=file size=30><br>\n";
print "<input type=radio name=source value=5> $text{'upgrade_url'}\n";
print "<input name=url size=40><br>\n";
print "<input type=radio name=source value=2 checked> $text{'upgrade_ftp'}<br>\n";
if (!$mode && !$dir) {
	print "<p><input type=checkbox name=delete value=1> ",
		"$text{'upgrade_delete'}<br>\n";
	}
print "<input type=checkbox name=force value=1> ",
	"$webmin::text{'upgrade_force'}<br>\n";
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'upgrade_ok'}\">\n";
print "</form>\n";

print &ui_hr();

print "$text{'update_desc1'}<p>\n";

print "<form action=update.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'update_header1'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";

printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
printf "<input name=other size=30 value='%s'><br>\n",
	$config{'upsource'};

printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
	$config{'upshow'} ? "checked" : "", $text{'update_show'};
printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
	$config{'upmissing'} ? "checked" : "", $text{'update_missing'};
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'update_ok'}\">\n";
print "</form>\n";

print &ui_hr();

print "$text{'update_desc2'}<p>\n";

print "<form action=update_sched.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'update_header2'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
printf "<input type=checkbox name=enabled value=1 %s> %s<p>\n",
	$config{'update'} ? 'checked' : '', $text{'update_enabled'};
	
printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
printf "<input name=other size=30 value='%s'><br>\n",
	$config{'upsource'};

if ($config{'cron_mode'} == 0) {
	$upmins = sprintf "%2.2d", $config{'upmins'};
	print &webmin::text('update_sched2',
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
printf "<input type=checkbox name=quiet value=1 %s> %s<br>\n",
      $config{'upquiet'} ? 'checked' : '', $text{'update_quiet'};
printf "%s <input name=email size=30 value='%s'><br>\n",
	$text{'update_email'}, $config{'upemail'};

print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'update_apply'}\">\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

