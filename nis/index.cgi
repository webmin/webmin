#!/usr/local/bin/perl
# index.cgi
# Display icons for NIS functions

require './nis-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("NIS", "man", "howto"));

if (!&get_nis_support()) {
	print "<p><b>$text{'index_enis'} $text{'index_enis2'}</b><p>\n";
	}

@icons =  ( "images/client.gif", "images/switch.gif",
	    "images/server.gif", "images/tables.gif",
	    "images/security.gif" );
@titles = ( $text{'client_title'}, $text{'switch_title'},
	    $text{'server_title'}, $text{'tables_title'},
	    $text{'security_title'} );
@links =  ( "edit_client.cgi", "list_switches.cgi",
	    "edit_server.cgi", "edit_tables.cgi",
	    "edit_security.cgi" );
&icons_table(\@links, \@titles, \@icons, 5);

&ui_print_footer("/", $text{'index'});

