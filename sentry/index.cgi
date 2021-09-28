#!/usr/local/bin/perl
# index.cgi
# Display icons for portsentry, hostsentry and logcheck options

require './sentry-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Find out which programs are installed
if (!&has_command($config{'portsentry'}) &&
    !-r $config{'hostsentry'} &&
    !&has_command($config{'logcheck'})) {
	# None are ..
	print "<p>",&text('index_ecommands',
			  "<tt>$config{'portsentry'}</tt>",
			  "<tt>$config{'hostsentry'}</tt>",
			  "<tt>$config{'logcheck'}</tt>",
			  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	}
else {
	# Show icons
	@links = ( "edit_portsentry.cgi", "edit_hostsentry.cgi",
		   "edit_logcheck.cgi" );
	@titles = ( "$text{'portsentry_title'}<br>$text{'portsentry_below'}",
		    "$text{'hostsentry_title'}<br>$text{'hostsentry_below'}",
		    "$text{'logcheck_title'}<br>$text{'logcheck_below'}" );
	@icons = ( "images/portsentry.gif", "images/hostsentry.gif",
		   "images/logcheck.gif" );
	&icons_table(\@links, \@titles, \@icons);
	}

&ui_print_footer("/", $text{'index'});

