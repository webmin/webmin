#!/usr/local/bin/perl
# Show all connected players

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'conns_title'}, "");

&is_minecraft_server_running() || &error($text{'conns_edown'});

my @conns = &list_connected_players();

if (@conns) {
	print $text{'conns_desc'},"<p>\n";
	my @grid;
	@grid = map { &ui_checkbox("d", $_)." ".
		      &ui_link("view_conn.cgi?name=".&urlize($_),
			       &html_escape($_)) } @conns;
	print &ui_form_start("mass_conns.cgi", "post");
	my @links = ( &select_all_link("d"),
		      &select_invert_link("d") );
	print &ui_links_row(\@links);
	print &ui_grid_table(\@grid, 8, "100%");
	print &ui_links_row(\@links);
	print &ui_form_end([
		[ "disc", $text{'conns_disc'} ],
		]);
	}
else {
	print "<b>$text{'conns_none'}</b><p>\n";
	}

print &ui_form_start("view_conn.cgi");
print "<b>$text{'conns_enter'}</b> ",
      &ui_textbox("name", undef, 20)." ".
      &ui_submit($text{'conns_ok'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});
