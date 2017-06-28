#!/usr/local/bin/perl
# search.cgi
# Display a list of packages where the name or description matches some string

require './software-lib.pl';
&ReadParse();

$in{'search'} || &error($text{'search_esearch'});
if (defined(&package_search)) {
	# Use system-specific search function
	$n = &package_search($in{'search'});
	@match = ( 0 .. $n-1 ) if ($n);
	}
else {
	# Search manually through entire list
	$n = &list_packages();
	$s = $in{'search'};
	for($i=0; $i<$n; $i++) {
		if ($packages{$i,'name'} =~ /\Q$s\E/i ||
		    $packages{$i,'desc'} =~ /\Q$s\E/i) {
			push(@match, $i);
			}
		}
	}
if (@match == 1 && $in{'goto'}) {
	$p = $packages{$match[0],'name'};
	$v = $packages{$match[0],'version'};
	&redirect("edit_pack.cgi?package=".&urlize($p)."&version=".&urlize($v));
	exit;
	}

&ui_print_header(undef, $text{'search_title'}, "", "search");

if (@match) {
	@match = sort { lc($packages{$a,'name'}) cmp lc($packages{$b,'name'}) }
		      @match;
	print "<b>",&text('search_match',
			  "<tt>".&html_escape($s)."</tt>"),"</b><p>\n";
	print &ui_form_start("delete_packs.cgi", "post");
	print &ui_hidden("search", $in{'search'});
	@tds = ( "width=5" );
	@links = ( &select_all_link("del", 0),
		   &select_invert_link("del", 0) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'search_pack'},
				  $text{'search_class'},
				  $text{'search_desc'} ], 100, 0, \@tds);
	foreach $i (@match) {
		local @cols;
		local $v = $packages{$i,'shortversion'} ||
			   $packages{$i,'version'};
		push(@cols, &ui_link("edit_pack.cgi?search=$s&package=".
		      &urlize($packages{$i,'name'})."&version=".
		      &urlize($packages{$i,'version'}), &html_escape(
			$packages{$i,'name'}.($v ?  " $v" : "")) ) );
		$c = $packages{$i,'class'};
		push(@cols, $c ? &html_escape($c)
				: $text{'search_none'});
		push(@cols, &html_escape($packages{$i,'desc'}));
		if ($packages{$i,'nouninstall'}) {
			print &ui_columns_row([ "", @cols ], \@tds);
			}
		else {
			print &ui_checked_columns_row(\@cols, \@tds, "del",
			      $packages{$i,'name'}." ".$packages{$i,'version'});
			}
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'search_delete'} ] ]);
	}
else {
	print "<b>",&text('search_nomatch', "<tt>$s</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

