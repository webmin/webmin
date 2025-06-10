#!/usr/local/bin/perl
# list_refresh.cgi
# Display all refresh patterns

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ui_print_header(undef, $text{'refresh_title'}, "", "list_refresh", 0, 0, 0,
		 &restart_button());
my $conf = &get_config();

my @refresh = &find_config("refresh_pattern", $conf);
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_refresh.cgi?new=1", $text{'refresh_add'}) );
if (@refresh) {
	print &ui_form_start("delete_refreshes.cgi", "post");
	my @tds = ( "width=5", undef, undef, undef, undef, "width=32" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'refresh_re'},
				  $text{'refresh_min'},
				  $text{'refresh_pc'},
				  $text{'refresh_max'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	my $hc = 0;
	foreach my $h (@refresh) {
		my @v = @{$h->{'values'}};
		if ($v[0] eq "-i") {
			shift(@v);
			}
		my @cols;
		push(@cols, &ui_link("edit_refresh.cgi?index=$h->{'index'}",
				     $v[0]));
		push(@cols, @v[1..3]);
		my $mover = &ui_up_down_arrows(
			"move_refresh.cgi?$hc+-1",
			"move_refresh.cgi?$hc+1",
			$hc != 0,
			$hc != @refresh-1);
		push(@cols, $mover);
		print &ui_checked_columns_row(\@cols, \@tds, "d",$h->{'index'});
		$hc++;
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'refresh_delete'} ] ]);
	}
else {
	print "<p>$text{'refresh_none'}<p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("", $text{'index_return'});

