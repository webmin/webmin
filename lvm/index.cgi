#!/usr/local/bin/perl
# index.cgi
# Display a table of all volume groups and their physical and logical volumes.

require './lvm-lib.pl';
&ReadParse();

if (!&has_command("vgdisplay")) {
	&lvm_header();
	print &text('index_ecommands', "<tt>vgdisplay</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
($lvm_version, $out) = &get_lvm_version();
if ($lvm_version && $lvm_version < 2) {
	# /proc/lvm doesn't exist in LVM 2
	if (!-d $lvm_proc) {
		system("modprobe lvm-mod >/dev/null 2>&1");
		}
	if (!-d $lvm_proc) {
		&lvm_header();
		print &text('index_emodule', "<tt>$lvm_proc</tt>",
				  "<tt>lvm-mod</tt>"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}
if (!$lvm_version) {
	&lvm_header();
	print &text('index_eversion', "<tt>vgdisplay --version</tt>",
			  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
&lvm_header();

@vgs = &list_volume_groups();
if (@vgs) {
	# Start tabs for volume groups, physical volumes and logical volumes
	@tabs = ( [ 'vgs', $text{'index_vgs'}, 'index.cgi?mode=vgs' ],
		  [ 'pvs', $text{'index_pvs'}, 'index.cgi?mode=pvs' ],
		  [ 'lvs', $text{'index_lvs'}, 'index.cgi?mode=lvs' ] );
	print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || 'vgs', 1);

	# Show volume groups
	print &ui_tabs_start_tab("mode", "vgs");
	print $text{'index_vgsdesc'},"<p>\n";
	@vgs = sort { $a->{'number'} <=> $b->{'number'} } @vgs;
	@links = ( &ui_link("edit_vg.cgi",$text{'index_add'}) );
	if ($config{'show_table'}) {
		# As table
		print &ui_links_row(\@links);
		print &ui_columns_start([ $text{'index_vgname'},
					  $text{'index_vgsize'},
					  $text{'index_vgtotal'},
					  $text{'index_vgtotal2'} ], 100);
		foreach $v (@vgs) {
			print &ui_columns_row([
			  "<a href='edit_vg.cgi?vg=".
			    &urlize($v->{'name'})."'>".
			    &html_escape($v->{'name'})."</a>",
			  &nice_size($v->{'size'}*1024),
			  &text('lv_petotals', $v->{'pe_alloc'},
					       $v->{'pe_total'}),
			  &text('lv_petotals',
			    &nice_size($v->{'pe_alloc'}*$v->{'pe_size'}*1024),
			    &nice_size($v->{'pe_total'}*$v->{'pe_size'}*1024))
			  ]);
			}
		print &ui_columns_end();
		}
	else {
		# As icons
		print &ui_links_row(\@links);
		foreach $v (@vgs) {
			push(@vgicons, "edit_vg.cgi?vg=".&urlize($v->{'name'}));
			push(@vgtitles, &html_escape($v->{'name'}).
					"<br>".&nice_size($v->{'size'}*1024));
			push(@vglinks, "images/vg.gif");
			}
		&icons_table(\@vgicons, \@vgtitles, \@vglinks);
		}
	print &ui_links_row(\@links);
	print &ui_tabs_end_tab();

	# Show physical volumes
	print &ui_tabs_start_tab("mode", "pvs");
	print $text{'index_pvsdesc'},"<p>\n";
	foreach $v (@vgs) {
		push(@allpvs, &list_physical_volumes($v->{'name'}));
		}
	@allpvs = sort { $a->{'name'} cmp $b->{'name'} } @allpvs;
	@links = ( );
	foreach $v (@vgs) {
		push(@links, "<a href='edit_pv.cgi?vg=".&urlize($v->{'name'}).
			     "'>".&text('index_addpv2', $v->{'name'})."</a>");
		}
	if (!@allpvs) {
		# None yet
		print "<b>$text{'index_nopvs2'}</b><p>\n";
		}
	elsif ($config{'show_table'}) {
		# Show table of PVs
		print &ui_links_row(\@links);
		print &ui_columns_start([ $text{'index_pvname'},
					  $text{'index_pvvg'},
					  $text{'index_pvsize'},
					  $text{'index_pvtotal'},
					  $text{'index_pvtotal2'} ], 100);
		foreach $p (@allpvs) {
			($v) = grep { $_->{'name'} eq $p->{'vg'} } @vgs;
			print &ui_columns_row([
			  "<a href='edit_pv.cgi?vg=".&urlize($v->{'name'}).
		            "&pv=".&urlize($p->{'name'})."'>$p->{'name'}</a>",
			  $v->{'name'},
			  &nice_size($p->{'size'}*1024),
			  &text('lv_petotals', $p->{'pe_alloc'},
					       $p->{'pe_total'}),
			  &text('lv_petotals',
			    &nice_size($p->{'pe_alloc'}*$p->{'pe_size'}*1024),
			    &nice_size($p->{'pe_total'}*$p->{'pe_size'}*1024)),
			  ]);
			}
		print &ui_columns_end();
		}
	else {
		# Show PV icons
		print &ui_links_row(\@links);
		foreach $p (@allpvs) {
			($v) = grep { $_->{'name'} eq $p->{'vg'} } @vgs;
			push(@pvicons, "edit_pv.cgi?vg=".&urlize($v->{'name'}).
				       "&pv=".&urlize($p->{'name'}));
			push(@pvtitles, &html_escape($p->{'name'}).
					"<br>".&nice_size($p->{'size'}*1024));
			push(@pvlinks, "images/vg.gif");
			}
		&icons_table(\@pvicons, \@pvtitles, \@pvlinks);
		}
	print &ui_links_row(\@links);
	print &ui_tabs_end_tab();

	# Show logical volumes
	print &ui_tabs_start_tab("mode", "lvs");
	print $text{'index_lvsdesc'},"<p>\n";
	foreach $v (@vgs) {
		push(@alllvs, &list_logical_volumes($v->{'name'}));
		}
	@alllvs = sort { $a->{'name'} cmp $b->{'name'} } @alllvs;
	@links = ( );
	foreach $v (@vgs) {
		push(@links, "<a href='edit_lv.cgi?vg=".&urlize($v->{'name'}).
			     "'>".&text('index_addlv2', $v->{'name'})."</a>");
		@lvsin = grep { $_->{'vg'} eq $v->{'name'} } @alllvs;
		if (@lvsin) {
			push(@links,
			  "<a href='edit_lv.cgi?vg=".&urlize($v->{'name'}).
			  "&snap=1'>".&text('index_addlv2s', $v->{'name'}).
			  "</a>");
			push(@links,
			  "<a href='thin_form.cgi?vg=".&urlize($v->{'name'}).
			  "'>".&text('index_addlv3', $v->{'name'}).
			  "</a>");
			}
		}
	if (!@alllvs) {
		# None yet
		print "<b>$text{'index_nolvs2'}</b><p>\n";
		}
	elsif ($config{'show_table'}) {
		# Show table of LVs
		print &ui_links_row(\@links);
		print &ui_columns_start([ $text{'index_lvname'},
					  $text{'index_lvvg'},
					  $text{'index_lvsize'},
					  $text{'index_lvused'},
					  $text{'index_lvuse'} ], 100);
		foreach $l (@alllvs) {
			($v) = grep { $_->{'name'} eq $l->{'vg'} } @vgs;
			my @thinc;
			if ($l->{'thin'}) {
				@thinc = grep { $_->{'thin_in'} eq
						$l->{'name'} } @alllvs;
				}
			if ($lv->{'is_snap'}) {
				($snapof) = grep {
					$_->{'size'} == $l->{'size'} &&
					$_->{'vg'} eq $l->{'vg'} &&
					$_->{'has_snap'} } @alllvs;
				}
			else {
				$snapof = undef;
				}
			@stat = &device_status($l->{'device'});
			$usedmsg = "";
			if (@stat[2]) {
				($total, $free) = &mount::disk_space(
					$stat[1], $stat[0]);
				if ($total) {
					$usedmsg = &text('lv_petotals',
						&nice_size(($total-$free)*1024),
						&nice_size($total*1024));
					}
				}
			print &ui_columns_row([
			  "<a href='edit_lv.cgi?vg=".&urlize($v->{'name'}).
		            "&lv=".&urlize($l->{'name'})."'>$l->{'name'}</a>",
			  $v->{'name'},
			  &nice_size(($l->{'cow_size'} || $l->{'size'})*1024),
			  $usedmsg,
			  (@stat ? &device_message(@stat) :
			   $l->{'thin'} ? &text('index_thin', scalar(@thinc)) :
					  undef).
			  ($snap ? " ".&text('index_snapof', $snap->{'name'})
				 : ""),
			  ]);
			}
		print &ui_columns_end();
		}
	else {
		# Show LV icons
		print &ui_links_row(\@links);
		foreach $l (@alllvs) {
			($v) = grep { $_->{'name'} eq $l->{'vg'} } @vgs;
			push(@lvicons, "edit_lv.cgi?vg=".&urlize($v->{'name'}).
				       "&lv=".&urlize($l->{'name'}));
			push(@lvtitles, &html_escape($l->{'name'}).
					"<br>".&nice_size(($l->{'cow_size'} || $l->{'size'})*1024));
			push(@lvlinks, "images/lv.gif");
			}
		&icons_table(\@lvicons, \@lvtitles, \@lvlinks);
		}
	print &ui_links_row(\@links);
	print &ui_tabs_end_tab();

	print &ui_tabs_end(1);
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	@tab = &list_lvmtab();
	if (@tab) {
		# Maybe LVM needs to be re-started
		print &text('index_init', "init.cgi"),"<p>\n";
		}
	print &ui_links_row([
		&ui_link("edit_vg.cgi",$text{'index_add'}) ]);
	}

&ui_print_footer("/", $text{'index'});

sub lvm_header
{
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("lvm", "man", "doc", "google"), undef, undef,
	$lvm_version ? &text('index_version', $lvm_version) : undef);
}

