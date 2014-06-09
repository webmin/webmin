#!/usr/local/bin/perl
# List all extents

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'extents_title'}, "");

my @extents = &find($conf, "extent");
my @links = ( &ui_link("edit_extent.cgi?new=1",$text{'extents_add'}) );
if (@extents) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_extents.cgi");
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ undef, 
				  $text{'extents_name'},
				  $text{'extents_file'},
				  $text{'extents_start'},
				  $text{'extents_size'} ], 100, 0, \@tds);
	foreach my $e (@extents) {
		print &ui_checked_columns_row([
			&ui_link("edit_extent.cgi?num=$e->{'num'}","$e->{'type'}.$e->{'num'}"),
			&mount::device_name($e->{'device'}),
			&nice_size($e->{'start'}),
			&nice_size($e->{'size'}),
			], \@tds, "d", $e->{'num'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'extents_delete'} ] ]);
	}
else {
	print "<b>$text{'extents_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
