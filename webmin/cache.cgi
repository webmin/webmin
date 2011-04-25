#!/usr/local/bin/perl
# Show a form for finding cached URLs, with the ability to flush

require './webmin-lib.pl';
&ui_print_header(undef, $text{'cache_title'}, "");
&ReadParse();

# Search form
print &ui_form_start("cache.cgi");
print "<b>$text{'cache_search'}</b>\n",
      &ui_textbox("search", $in{'search'}, 40),"\n",
      &ui_submit($text{'cache_ok'}),"\n";
print &ui_form_end();

if ($in{'search'}) {
	# Find results
	$surl = $in{'search'};
	$surl =~ s/\//_/g;
	foreach $c (&list_cached_files()) {
		if ($c->[0] =~ /\Q$surl\E/i) {
			my @st = stat($c->[1]);
			push(@urls, [ $c->[0], $c->[2], $st[7], $st[9] ]);
			}
		}

	if (@urls) {
		# Show the results
		print &text('cache_matches', scalar(@urls)),"<br>\n";
		@tds = ( "width=5" );
		print &ui_form_start("delete_cache.cgi", "post");
		print &ui_hidden("search", $in{'search'}),"\n";
		@links = ( &select_all_link("d", 1),
			   &select_invert_link("d", 1) );
		print &ui_links_row(\@links);
		print &ui_columns_start([ "", $text{'cache_url'},
					  $text{'cache_size'}, $text{'cache_date'} ],
					100, 0, \@tds);
		foreach $url (@urls) {
			print &ui_checked_columns_row(
			  [ $url->[1], &nice_size($url->[2]), &make_date($url->[3], 1) ],
			  \@tds, "d", $url->[0]);
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ "delete", $text{'cache_delete'} ] ]);
		}
	else {
		print "<b>$text{'cache_none'}</b><p>\n";
		}
	}

&ui_print_footer("edit_proxy.cgi", $text{'proxy_return'},
		 "", $text{'index_return'});

