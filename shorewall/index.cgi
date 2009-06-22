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
		print "<table width=100%>\n";
		system("$config{'shorewall'} status 2>&1");
		if ($?) {
		  # Down .. offer to start
		  # unless no permissions
		  unless ($access{'nochange'}) {
		    print "<form action=start.cgi>\n";
		    print "<tr> <td><input type=submit ",
		      "value='$text{'index_start'}'></td>\n";
		    print "<td>$text{'index_startdesc'}</td> </tr>\n";
		    print "</form>\n";
		  }
		}
		else {
		  # Up .. offer to restart, clear and stop
		  # unless nochange is set
		  unless ($access{'nochange'}) {
		    print "<form action=restart.cgi>\n";
		    print "<tr> <td><input type=submit ",
		      "value='$text{'index_restart'}'></td>\n";
		    print "<td>$text{'index_restartdesc'}</td> </tr>\n";
		    print "</form>\n";

		    print "<form action=refresh.cgi>\n";
		    print "<tr> <td><input type=submit ",
		      "value='$text{'index_refresh'}'></td>\n";
		    print "<td>$text{'index_refreshdesc'}</td> </tr>\n";
		    print "</form>\n";

		    print "<form action=clear.cgi>\n";
		    print "<tr> <td><input type=submit ",
		      "value='$text{'index_clear'}'></td>\n";
		    print "<td>$text{'index_cleardesc'}</td> </tr>\n";
		    print "</form>\n";

		    print "<form action=stop.cgi>\n";
		    print "<tr> <td><input type=submit ",
		      "value='$text{'index_stop'}'></td>\n";
		    print "<td>$text{'index_stopdesc'}</td> </tr>\n";
		    print "</form>\n";
		  }
		  print "<form action=status.cgi>\n";
		  print "<tr> <td><input type=submit ",
		    "value='$text{'index_status'}'></td>\n";
		  print "<td>$text{'index_statusdesc'}</td> </tr>\n";
		  print "</form>\n";
		}

		# Always offer to check
		print "<form action=check.cgi>\n";
		print "<tr> <td><input type=submit ",
		      "value='$text{'index_check'}'></td>\n";
		print "<td>$text{'index_checkdesc'}</td> </tr>\n";
		print "</form>\n";
		print "<form action=dump.cgi>\n";
		print "<tr> <td><input type=submit ",
		  "value='$text{'index_dump'}'></td>\n";
		print "<td>$text{'index_dumpdesc'}</td> </tr>\n";
		print "</form>\n";
		print "</table>\n";
		}
	}

&ui_print_footer("/", $text{'index'});

