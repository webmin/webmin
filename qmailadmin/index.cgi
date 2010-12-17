#!/usr/local/bin/perl
# index.cgi
# Display icons for various things that can be configured in qmail

require './qmail-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("qmail", "man:$config{'qmail_dir'}/man", "google"));

# Check if qmail is installed
if (!-d $config{'qmail_dir'}) {
	print &text('index_edir', "<tt>$config{'qmail_dir'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if (!-d $qmail_alias_dir || !-d $qmail_bin_dir) {
	print &text('index_edir2', "<tt>$config{'qmail_dir'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@olinks = ( "list_opts.cgi", "list_aliases.cgi", "list_virts.cgi",
	    "list_locals.cgi", "list_rcpts.cgi", "list_bads.cgi",
	    "list_routes.cgi", "list_percents.cgi", "list_assigns.cgi",
	    "list_queue.cgi",
	    &foreign_available("mailboxes") ? ( "../mailboxes/" ) : ( ) );

if (!$config{'mailq_count'}) {
	@queue = &list_queue();
	}
@otitles = ( "$text{'opts_title'}<br>(control)</tt>",
	     "$text{'aliases_title'}<br>(alias)",
	     "$text{'virts_title'}<br>(virtualdomains)",
	     "$text{'locals_title'}<br>(locals)",
	     "$text{'rcpts_title'}<br>(rcpthosts)",
	     "$text{'bads_title'}<br>(badmailfrom)",
	     "$text{'routes_title'}<br>(smtproutes)",
	     "$text{'percents_title'}<br>(percenthack)",
	     "$text{'assigns_title'}<br>(assign)",
	     scalar(@queue) ?
	       "$text{'queue_title'}<br>".&text('queue_count', scalar(@queue)) :
	       "$text{'queue_title'}<br>(qmail-qread)",
	     $text{'boxes_title'} );

@oicons = ( "images/opts.gif", "images/aliases.gif", "images/virts.gif",
	    "images/locals.gif", "images/rcpts.gif", "images/bads.gif",
	    "images/routes.gif", "images/percents.gif", "images/assigns.gif",
	    "images/queue.gif", "images/boxes.gif" );

&icons_table(\@olinks, \@otitles, \@oicons);

# Check if the qmail processes are running
print &ui_hr();
print &ui_buttons_start();
if (&is_qmail_running()) {
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopmsg'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      &text('index_startmsg',
				"<tt>$qmail_start_cmd</tt>"));
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

