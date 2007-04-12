#!/usr/local/bin/perl
# list_refresh.cgi
# Display all refresh patterns

require './squid-lib.pl';
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ui_print_header(undef, $text{'refresh_title'}, "", "list_refresh", 0, 0, 0, &restart_button());
$conf = &get_config();

@refresh = &find_config("refresh_pattern", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   "<a href='edit_refresh.cgi?new=1'>$text{'refresh_add'}</a>" );
if (@refresh) {
	print &ui_form_start("delete_refreshes.cgi", "post");
	@tds = ( "width=5", undef, undef, undef, undef, "width=32" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'refresh_re'},
				  $text{'refresh_min'},
				  $text{'refresh_pc'},
				  $text{'refresh_max'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	$hc = 0;
	foreach $h (@refresh) {
		@v = @{$h->{'values'}};
		if ($v[0] eq "-i") {
			shift(@v);
			}
		local @cols;
		push(@cols, "<a href='edit_refresh.cgi?index=$h->{'index'}'>$v[0]</a>");
		push(@cols, @v[1..3]);
		local $mover;
		if ($hc != @refresh-1) {
			$mover .= "<a href=\"move_refresh.cgi?$hc+1\">".
			          "<img src=images/down.gif border=0></a>";
			}
		else {
			$mover .= "<img src=images/gap.gif>";
			}
		if ($hc != 0) {
			$mover .= "<a href=\"move_refresh.cgi?$hc+-1\">".
			          "<img src=images/up.gif border=0></a>";
			}
		else {
			$mover .= "<img src=images/gap.gif>";
			}
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

