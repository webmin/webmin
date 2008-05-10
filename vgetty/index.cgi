#!/usr/local/bin/perl
# index.cgi
# Displays a table of option category icons

require './vgetty-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("vgetty", "man", "doc"));

# Check if vgetty is actually installed
if (!&has_command($config{'vgetty_cmd'})) {
	print "<p>",&text('index_ecmd', "<tt>$config{'vgetty_cmd'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if config file exists
if (!-r $config{'vgetty_config'}) {
	print "<p>",&text('index_econfig', "<tt>$config{'vgetty_config'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Show icons for various option categories
@titles = ( $text{'vgetty_title'}, $text{'options_title'},
	    $text{'received_title'}, $text{'messages_title'} );
@links = ( "list_vgetty.cgi", "edit_options.cgi", "list_received.cgi",
	   "list_messages.cgi" );
@icons = ( "images/vgetty.gif", "images/options.gif", "images/received.gif",
	   "images/messages.gif" );
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print "<form action=vgetty_apply.cgi>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'vgetty_apply'}'></td>\n";
print "<td>",&text('vgetty_applydesc', "<tt>telinit q</tt>"),"</td>\n";
print "</tr></table></form>\n";

&ui_print_footer("/", $text{'index'});

