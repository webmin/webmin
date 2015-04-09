#!/usr/local/bin/perl
# index.cgi
# Show fetchmail configurations

require './fetchmail-lib.pl';

# Check if fetchmail is installed
if (!&has_command($config{'fetchmail_path'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("fetchmail", "doc", "man", "google"));
	print "<p>",&text('index_efetchmail',
			  "<tt>$config{'fetchmail_path'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Get and show the version
$ver = &get_fetchmail_version();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("fetchmail", "doc", "man", "google"), undef, undef,
	&text('index_version', $ver));

if ($config{'config_file'}) {
	# Just read one config file
	@conf = &parse_config_file($config{'config_file'});
	@conf = grep { $_->{'poll'} } @conf;
	print "<b>",&text('index_file',
			  "<tt>$config{'config_file'}</tt>"),"</b><p>\n";
	&show_polls(\@conf, $config{'config_file'}, $config{'daemon_user'});

	local @uinfo = getpwnam($config{'daemon_user'});
	print &ui_hr();
	print "<table width=100%>\n";

	if (&foreign_installed("cron") && $access{'cron'}) {
		# Show button to manage cron job
		print "<form action=edit_cron.cgi>\n";
		print "<tr> <td><input type=submit ",
		      "value='$text{'index_cron'}'></td>\n";
		print "<td>$text{'index_crondesc'}</td> </tr></form>\n";
		}

	# Show the fetchmail daemon form
	foreach $pf ($config{'pid_file'},
		     "$uinfo[7]/.fetchmail.pid", "$uinfo[7]/.fetchmail") {
		if (open(PID, $pf) && ($line=<PID>) &&
		    (($pid,$interval) = split(/\s+/, $line)) && $pid &&
		    kill(0, $pid)) {
			$running++;
			last;
			}
		}
	print "<tr><td>\n";
	if ($running) {
		# daemon is running - offer to stop it
		print "<form action=stop.cgi>\n";
		print "<input type=submit value='$text{'index_stop'}'></td>\n";
		print "<td>",&text('index_stopmsg',
				   "<tt>$config{'daemon_user'}</tt>",
				   $interval),"</td>\n";
		}
	else {
		# daemon isn't running - offer to start it
		print "<form action=start.cgi>\n";
		print "<input type=submit value='$text{'index_start'}'></td>\n";
		print "<td>",&text('index_startmsg',
				   "<input name=interval size=5 value='60'>",
				   "<tt>$config{'daemon_user'}</tt>"),"</td>\n";
		}
	print "</td></tr></table></form>\n";
	}
else {
	# Build a list of users with fetchmail configurations
	$ucount = 0;
	setpwent();
	while(@uinfo = getpwent()) {
		next if ($donehome{$uinfo[7]}++);
		next if (!&can_edit_user($uinfo[0]));
		local @conf = &parse_config_file("$uinfo[7]/.fetchmailrc");
		@conf = grep { $_->{'poll'} } @conf;
		if (@conf) {
			push(@users, [ \@conf, [ @uinfo ] ]);
			}
		$ucount++;
		last if ($config{'max_users'} &&
			 $ucount > $config{'max_users'});
		}
	endpwent() if ($gconfig{'os_type'} ne 'hpux');
	@users = sort { $a->[1]->[0] cmp $b->[1]->[0] } @users;
	if (!@users) {
		# None found
		print "<br><b>$text{'index_none'}</b><p>\n";
		}
	elsif ($config{'max_users'} && $ucount > $config{'max_users'}) {
		# Show user search form
		print "$text{'index_toomany'}<p>\n";
		print &ui_form_start("edit_user.cgi");
		print "<b>$text{'index_search'}</b>\n";
		print &ui_user_textbox("user", undef, 20),"\n";
		print &ui_submit($text{'index_show'}),"\n";
		print &ui_form_end();
		$toomany = 1;
		}
	elsif (!$config{'view_mode'}) {
		# Full details
		&show_button();
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'index_user'}</b></td> <td><b>$text{'index_conf'}</b></td> </tr>\n";
		foreach $u (@users) {
			print "<tr $cb>\n";
			print "<td valign=top><b>",&html_escape($u->[1]->[0]),
			      "</b></td> <td>\n";
			&show_polls($u->[0], "$u->[1]->[7]/.fetchmailrc",
				    $u->[1]->[0]);
			print "</td> </tr>\n";
			}
		print "</table>\n";
		}
	else {
		# Just show usernames
		print &ui_table_start($text{'index_header'}, "width=100%", 1);
		$i = 0;
		foreach $u (@users) {
			print "<tr>\n" if ($i%4 == 0);
			print &ui_link("edit_user.cgi?user=$u->[1]->[0]","$u->[1]->[0]")."</td>\n";
			print "</tr>\n" if ($i%4 == 3);
			$i++;
			}
		print &ui_table_end();
		}
	&show_button() if (!$toomany);

	if (&foreign_installed("cron") && $access{'cron'}) {
		# Show button to manage global cron job
		print &ui_hr();
		print &ui_buttons_start();
		print &ui_buttons_row("edit_cron.cgi",
				      $text{'index_cron'}, $text{'index_crondesc2'});
		print &ui_buttons_end();
		}
	}

&ui_print_footer("/", $text{'index'});

sub show_button
{
if ($access{'mode'} != 3 || !$doneheader) {
	print "<form action=edit_poll.cgi>\n";
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value='$text{'index_ok'}'>\n";
	print &unix_user_input("user");
	print "</form>\n";
	}
}

