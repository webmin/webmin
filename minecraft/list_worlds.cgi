#!/usr/local/bin/perl
# Show all known world directories

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'worlds_title'}, "");

my @worlds = &list_worlds();
my $conf = &get_minecraft_config();
my $def = &find_value("level-name", $conf);

my @links = ( &ui_link("edit_world.cgi?new=1",$text{'worlds_new'}) );
if (@worlds) {
	my @tds = ( "width=5%" );
	print &ui_form_start("change_world.cgi");
	print &ui_links_row(\@links);
	print &ui_columns_start([
		$text{'worlds_def'},
		$text{'worlds_name'},
		$text{'worlds_size'},
		$text{'worlds_players'},
		], undef, 0, \@tds);
	foreach my $w (@worlds) {
		my @p = @{$w->{'players'}};
		if (@p > 5) {
			@p = ( @p[0..4], "..." );
			}
		print &ui_columns_row([
			&ui_oneradio("d", $w->{'name'}, "",
				     $w->{'name'} eq $def),
			"<a href='edit_world.cgi?name=".&urlize($w->{'name'}).
			  "'>".&html_escape($w->{'name'})."</a>",
			&nice_size($w->{'size'}),
			join(" , ", @p),
			], \@tds);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'worlds_change'} ],
			     &is_minecraft_server_running() ?
				( [ 'apply', $text{'worlds_change2'} ] ) :
				( ) ]);
	}
else {
	print "<b>$text{'worlds_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
