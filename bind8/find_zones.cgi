#!/usr/local/bin/perl
# find_zones.cgi
# Display zones matching some search
use strict;
use warnings;
our (%in, %config, %text); 

require './bind8-lib.pl';
&ReadParse();

if (&have_dnssec_tools_support()) {
	# Parse the rollrec file to determine zone status
	&lock_file($config{"dnssectools_rollrec"});
	rollrec_lock();
	rollrec_read($config{"dnssectools_rollrec"});
}

my @zones = &list_zone_names();
my (@zlinks, @ztitles, @zdels, @ztypes, @zstatus, @zicons);
my $len;
foreach my $z (@zones) {
	my $v = $z->{'name'};
	next if ($z->{'type'} eq 'view' ||
		 $v eq "." || !&can_edit_zone($z) ||
		 &arpa_to_ip($v) !~ /\Q$in{'search'}\E/i);
	my $t = $z->{'type'};
	if ($z->{'view'}) {
		push(@zlinks, "edit_$t.cgi?zone=$z->{'name'}".
			      "&view=$z->{'viewindex'}");
		push(@ztitles, &ip6int_to_net(&arpa_to_ip($v))." ".
		       &text('index_view', "<tt>$z->{'view'}</tt>"));
		push(@zdels, $z->{'index'}." ".$z->{'view'});
		}
	else {
		push(@zlinks, "edit_$t.cgi?zone=$z->{'name'}");
		push(@ztitles, &ip6int_to_net(&arpa_to_ip($v)));
		push(@zdels, $z->{'index'});
		}
	push(@zicons, "images/$t.gif");
	push(@ztypes, $text{"index_$t"});
	if (&have_dnssec_tools_support()) {
		my $rrr = rollrec_fullrec($v);
		if ($rrr) {
			if($rrr->{'kskphase'} > 0) {
				if($rrr->{'kskphase'} == 6) {
					push(@zstatus, $text{"dt_status_waitfords"});
				} else {
					push(@zstatus, $text{"dt_status_inKSKroll"});
				}
			} elsif($rrr->{'zskphase'} > 0) {
				push(@zstatus, $text{"dt_status_inZSKroll"});
			} else {
				push(@zstatus, $text{"dt_status_signed"});
			}
		} else {
			push(@zstatus, $text{"dt_status_unsigned"});
		}
	}

	$len++;
	}

if (&have_dnssec_tools_support()) {
	rollrec_close();
	rollrec_unlock();
	&unlock_file($config{"dnssectools_rollrec"});
}


if (@zlinks == 1) {
	&redirect($zlinks[0]);
	exit;
	}

&ui_print_header(undef, $text{'find_title'}, "");
print &text('find_match', "<tt>".&html_escape($in{'search'})."</tt>"),"<p>\n";

if ($len) {
	# sort list of zones
	my @zorder = sort { $ztitles[$a] cmp $ztitles[$b] } (0 .. $len-1);
	@zlinks = map { $zlinks[$_] } @zorder;
	@ztitles = map { $ztitles[$_] } @zorder;
	@zicons = map { $zicons[$_] } @zorder;
	@ztypes = map { $ztypes[$_] } @zorder;
	@zdels = map { $zdels[$_] } @zorder;
	@zstatus = map { $zstatus[$_] } @zorder;

	if ($config{'show_list'}) {
		# display as list
		my $mid = int((@zlinks+1)/2);
		print &ui_form_start("mass_delete.cgi", "post");
		my @links = ( &select_all_link("d", 0),
			   &select_invert_link("d", 0) );
		print &ui_links_row(\@links);
		my @grid = ( );
		if (&have_dnssec_tools_support()) {
		push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
				      [ @ztitles[0 .. $mid-1] ],
				      [ @ztypes[0 .. $mid-1] ],
									  [ @zdels[0 .. $mid-1] ],
									  [ @zstatus[0 .. $mid-1] ] ));
		} else {
			push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
					  [ @ztitles[0 .. $mid-1] ],
					  [ @ztypes[0 .. $mid-1] ],
									  [ @zdels[0 .. $mid-1] ] ));
		}
		if ($mid < @zlinks) {
			if (&have_dnssec_tools_support()) {
			push(@grid, &zones_table([ @zlinks[$mid .. $#zlinks] ],
					     [ @ztitles[$mid .. $#ztitles] ],
					     [ @ztypes[$mid .. $#ztypes] ],
					     [ @zdels[$mid .. $#zdels] ],
					     [ @zstatus[$mid .. $#zstatus] ]));
			} else {
			push(@grid, &zones_table([ @zlinks[$mid .. $#zlinks] ],
						 [ @ztitles[$mid .. $#ztitles] ],
						 [ @ztypes[$mid .. $#ztypes] ],
											 [ @zdels[$mid .. $#zdels] ] ));
			}
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


