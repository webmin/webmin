#!/usr/bin/perl
# index.cgi
# Display icons for the various shorewall configuration files

require './shorewall-lib.pl';

if (!&has_command($config{'shorewall'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>",&text('index_ecmd', "<tt>$config{'shorewall'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	}
else {
	# Get the version
	$shorewall_version = &get_shorewall_version(1);
	&open_tempfile(VERSION, ">$module_config_directory/version");
	&print_tempfile(VERSION, $shorewall_version,"\n");
	&close_tempfile(VERSION);

	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("shorewall", "doc", "google"),
		undef, undef, &text('index_version', &get_printable_version($shorewall_version)));

	if (!-d $config{'config_dir'}) {
		# Config dir not found!
		print "<p>",&text('index_edir',
		      "<tt>$config{'config_dir'}</tt>",
		      "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		}
	else {
		# Just show the file icons
		@files = grep { &can_access($_) } @shorewall_files;
		@titles = map { $text{&clean_name($_)."_title"}."<br>($_)" } @files;
		@links = map { "list.cgi?table=".$_ } @files;
		@icons = map { "images/".$_.".gif" } @files;
		&icons_table(\@links, \@titles, \@icons, 4);

		# Check if shorewall is running by looking for the 'shorewall'
		# chain in the filter table
		print &ui_hr();
		print &ui_buttons_start();
		my $ex = system("$config{'shorewall'} status 2>&1");

		if ($ex && !$access{'nochange'}) {
			# Down .. offer to start
			print &ui_buttons_row(
				"start.cgi",
				$text{'index_start'},
				$text{'index_startdesc'});
			}
		elsif (!$ex && !$access{'nochange'}) {
			# Up .. offer to restart, clear and stop
			print &ui_buttons_row(
				"restart.cgi",
				$text{'index_restart'},
				$text{'index_restartdesc'});

			print &ui_buttons_row(
				"refresh.cgi",
				$text{'index_refresh'},
				$text{'index_refreshdesc'});

			print &ui_buttons_row(
				"clear.cgi",
				$text{'index_clear'},
				$text{'index_cleardesc'});

			print &ui_buttons_row(
				"stop.cgi",
				$text{'index_stop'},
				$text{'index_stopdesc'});
			}
		if (!$ex) {
			print &ui_buttons_row(
				"status.cgi",
				$text{'index_status'},
				$text{'index_statusdesc'});
			}

		# Check and dump buttons
		print &ui_buttons_row(
			"check.cgi",
			$text{'index_check'},
			$text{'index_checkdesc'});
		print &ui_buttons_row(
			"dump.cgi",
			$text{'index_dump'},
			$text{'index_dumpdesc'});

		print &ui_buttons_end();
		}
	}

&ui_print_footer("/", $text{'index'});

