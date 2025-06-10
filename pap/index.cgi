#!/usr/local/bin/perl
# index.cgi
# Displays a menu of PPP server related icons

require './pap-lib.pl';

# Show icons for various option categories
@links = ( "list_mgetty.cgi", "edit_options.cgi", "list_dialin.cgi",
	   "list_secrets.cgi" );
@links = grep { /_(.*).cgi/; $access{$1} } @links;
@titles = map { /_(.*).cgi/; $text{$1."_title"} } @links;
@icons = map { /_(.*).cgi/; "images/$1.gif" } @links;

if (@links == 1 && $access{'direct'}) {
	&redirect($links[0]);
	exit;
	}
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

if (@links) {
	&icons_table(\@links, \@titles, \@icons);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});

