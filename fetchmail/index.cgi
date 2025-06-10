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
			  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
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
	print &show_polls(\@conf, $config{'config_file'}, $config{'daemon_user'});

	print &ui_hr();
	print &ui_buttons_start();

	if (&foreign_installed("cron") && $access{'cron'}) {
		# Show button to manage cron job
		print &ui_buttons_row("edit_cron.cgi", $text{'index_cron'},
				      $text{'index_crondesc'});
		}

	# Show the fetchmail daemon form
	if (&is_fetchmail_running()) {
		# daemon is running - offer to stop it
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			&text('index_stopmsg',
			      "<tt>$config{'daemon_user'}</tt>",
			      $interval));
		}
	else {
		# daemon isn't running - offer to start it
		print &ui_buttons_row("start.cgi", $text{'index_start'},
			&text('index_startmsg', &ui_textbox("interval", 60, 5),
			      "<tt>$config{'daemon_user'}</tt>"));
		}
	print &ui_buttons_end();
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
		print &ui_columns_start([ $text{'index_user'}, $text{'index_conf'} ], 100);
		foreach $u (@users) {
			print &ui_columns_row([
				&html_escape($u->[1]->[0]),
				&show_polls($u->[0], "$u->[1]->[7]/.fetchmailrc",
					    $u->[1]->[0]) ]);
			}
		print &ui_columns_end();
		}
	else {
		# Just show usernames
		my @grid;
		foreach $u (@users) {
			push(@grid, &ui_link("edit_user.cgi?user=$u->[1]->[0]","$u->[1]->[0]"));
			}
		print &ui_table_start($text{'index_header'}, "width=100%", 1);
		print &ui_table_row(undef, &ui_grid_table(\@grid, 4));
		print &ui_table_end();
		}
	if (!$toomany) {
		&show_button(1);
		# Only display the bottom form when there are too many users,
		# i.e. requiring page scrolling
		print &ui_hide_outside_of_viewport();
		}

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
my $bottom = shift;
my $bottom_form;
$bottom_form = 'data-outside-of-viewport' if ($bottom);
if ($access{'mode'} != 3 || !$doneheader) {
	print &ui_form_start("edit_poll.cgi", "get", undef, $bottom_form);
	print &ui_hidden("view", 1);
	print &ui_submit($text{'index_fadd'});
	print &unix_user_input("user");
	print &ui_form_end();
	}
}

