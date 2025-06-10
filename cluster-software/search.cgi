#!/usr/local/bin/perl
# search.cgi
# Display a list of packages where the name or description matches some string

require './cluster-software-lib.pl';
&ReadParse();

$s = $in{'search'};
@hosts = &list_software_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	$anymatch = 0;
	foreach $p (@{$h->{'packages'}}) {
		if (($p->{'name'} =~ /\Q$s\E/i || $p->{'desc'} =~ /\Q$s\E/i) &&
		    !$already{$p->{'name'}}++) {
			push(@match, $p);
			$anymatch = 1;
			}
		}
	if ($anymatch) {
		push(@servs, &host_to_server($h));
		}
	}
if (@match == 1) {
	&redirect("edit_pack.cgi?package=".&urlize($match[0]->{'name'}));
	exit;
	}

&ui_print_header(undef, $text{'search_title'}, "", "search");
if (@match) {
	@match = sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @match;
	print "<b>",&text('search_match', "<tt>".&html_escape($s)."</tt>"),"</b><br>\n";

	print &ui_form_start("delete_packs.cgi", "post");
	print &ui_hidden("search", $in{'search'}),"\n";
	@links = ( &select_all_link("del", 0),
		   &select_invert_link("del", 0) );
	@tds = ( "width=5" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'search_pack'},
				  $text{'search_class'},
				  $text{'search_desc'} ], 100, 0, \@tds);
	foreach $i (@match) {
		local @cols;
		push(@cols, "<a href=\"edit_pack.cgi?search=".&urlize($s).
		    "&package=".&urlize($i->{'name'})."\">$i->{'name'}</a>");
		$c = $i->{'class'};
		push(@cols, $i->{'class'} || $text{'search_none'});
		push(@cols, $i->{'desc'});
		print &ui_checked_columns_row(\@cols, \@tds,
					      "del", $i->{'name'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);

	# Show button to delete, and servers to remove from
	print &ui_submit($text{'search_delete'}),"\n";
	print &ui_select("server", undef,
			 [ [ -1, $text{'edit_all'} ],
			   map { [ $_->{'id'}, &server_name($_) ] } @servs ]);
	print &ui_form_end();
	}
else {
	print "<b>",&text('search_nomatch', "<tt>".&html_escape($s)."</tt>"),"</b>\n";
	}

&ui_print_footer("", $text{'index_return'});

