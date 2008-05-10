#!/usr/local/bin/perl
# index.cgi

require './mon-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "","intro", 1, 1, 0
	&help_search_link("mon", "man", "doc", "google"));

# Check if mon is installed
if (!-r $mon_config_file) {
	print "<p>",&text('err_nomonconf', "<tt>$mon_config_file</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# print icons
@opts 	= ( 'global', 'groups', 'watches', 'periods', 'users', 'auth',
	    'status', 'show' );
@links 	= ( 'edit_global.cgi', 'list_groups.cgi', 'list_watches.cgi',
	    'list_periods.cgi', 'list_users.cgi', 'edit_auth.cgi', 'mon.cgi',
	    'monshow.cgi' );
@titles = map { $text{"${_}_title"} } @opts;
@icons 	= map { "images/${_}.gif" } @opts;
&icons_table(\@links, \@titles, \@icons);

# check if mon is running
print &ui_hr();
print "<table width=100%>\n";
if (&check_pid_file($config{'pid_file'})) {
	print "<tr><form action=stop.cgi>\n";
	print "<td><input type=submit value=\"$text{'mon_stop'}\"></td>\n";
	print "<td>$text{'mon_stopdesc'}</td>\n";
	print "</form></tr>\n";

	print "<tr><form action=restart.cgi>\n";
	print "<td><input type=submit value=\"$text{'mon_restart'}\"></td>\n";
	print "<td>$text{'mon_restartdesc'}</td>\n";
	print "</form></tr>\n";
	close(PID);
	}
else {
	print "<tr><form action=start.cgi>\n";
	print "<td><input type=submit value=\"$text{'mon_start'}\"></td>\n";
	print "<td>$text{'mon_startdesc'}</td>\n";
	print "</form></tr>\n";
	}
print "</table>\n";

&ui_print_footer("/", $text{'index'});

