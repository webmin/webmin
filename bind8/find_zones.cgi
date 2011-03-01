#!/usr/local/bin/perl
# find_zones.cgi
# Display zones matching some search

require './bind8-lib.pl';
&ReadParse();

@zones = &list_zone_names();
foreach $z (@zones) {
	$v = $z->{'name'};
	next if ($z->{'type'} eq 'view' ||
		 $v eq "." || !&can_edit_zone($z) ||
		 &arpa_to_ip($v) !~ /\Q$in{'search'}\E/i);
	$t = $z->{'type'};
	if ($z->{'view'}) {
		push(@zlinks, "edit_$t.cgi?index=$z->{'index'}".
			      "&view=$z->{'viewindex'}");
		push(@ztitles, &ip6int_to_net(&arpa_to_ip($v))." ".
		       &text('index_view', "<tt>$z->{'view'}</tt>"));
		push(@zdels, $z->{'index'}." ".$z->{'view'});
		}
	else {
		push(@zlinks, "edit_$t.cgi?index=$z->{'index'}");
		push(@ztitles, &ip6int_to_net(&arpa_to_ip($v)));
		push(@zdels, $z->{'index'});
		}
	push(@zicons, "images/$t.gif");
	push(@ztypes, $text{"index_$t"});
	$len++;
	}
if (@zlinks == 1) {
	&redirect($zlinks[0]);
	exit;
	}

&ui_print_header(undef, $text{'find_title'}, "");
print &text('find_match', "<tt>".&html_escape($in{'search'})."</tt>"),"<p>\n";

if ($len) {
	# sort list of zones
	@zorder = sort { $ztitles[$a] cmp $ztitles[$b] } (0 .. $len-1);
	@zlinks = map { $zlinks[$_] } @zorder;
	@ztitles = map { $ztitles[$_] } @zorder;
	@zicons = map { $zicons[$_] } @zorder;
	@ztypes = map { $ztypes[$_] } @zorder;
	@zdels = map { $zdels[$_] } @zorder;

	if ($config{'show_list'}) {
		# display as list
		$mid = int((@zlinks+1)/2);
		print &ui_form_start("mass_delete.cgi", "post");
		@links = ( &select_all_link("d", 0),
			   &select_invert_link("d", 0) );
		print &ui_links_row(\@links);
		@grid = ( );
		push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
				      [ @ztitles[0 .. $mid-1] ],
				      [ @ztypes[0 .. $mid-1] ],
				      [ @zdels[0 .. $mid-1] ] ));
		if ($mid < @zlinks) {
			push(@grid, &zones_table([ @zlinks[$mid .. $#zlinks] ],
					     [ @ztitles[$mid .. $#ztitles] ],
					     [ @ztypes[$mid .. $#ztypes] ],
					     [ @zdels[$mid .. $#zdels] ]));
			}
		print &ui_grid_table(\@grid, 2, 100,
				     [ "width=50%", "width=50%" ]);
		print &ui_links_row(\@links);
		print &ui_form_end([ [ "delete", $text{'index_massdelete'} ],
				     [ "update", $text{'index_massupdate'} ],
				     [ "create", $text{'index_masscreate'} ] ]);
		}
	else {
		# display as icons
		&icons_table(\@zlinks, \@ztitles, \@zicons);
		}
	}
else {
	print "<b>$text{'find_none'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});


