#!/usr/local/bin/perl
# Display a form for editing an existing logical volume

require './lvm-lib.pl';
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});
@lvs = &list_logical_volumes($in{'vg'});
@thins = grep { $_->{'thin'} } @lvs;
@pvs = &list_physical_volumes($in{'vg'});

$vgdesc = &text('lv_vg', $vg->{'name'});
if ($in{'lv'}) {
	($lv) = grep { $_->{'name'} eq $in{'lv'} } @lvs;
	$lv || &error($text{'lv_egone'});
	&ui_print_header($vgdesc, $lv->{'is_snap'} ? $text{'lv_edit_snap'}
				 : $text{'lv_edit'}, "");
	@stat = &device_status($lv->{'device'});
	}
else {
	&ui_print_header($vgdesc, $in{'snap'} ? $text{'lv_create_snap'} : $text{'lv_create'},"");
	$lv = { 'perm' => 'rw',
		'alloc' => 'n',
		'is_snap' => $in{'snap'},
	 	'size' => ($vg->{'pe_total'} - $vg->{'pe_alloc'})*
			  $vg->{'pe_size'} };
	$lv->{'size'} = &nice_round($lv->{'size'});
	}

print &ui_form_start("save_lv.cgi");
print &ui_hidden("vg", $in{'vg'});
print &ui_hidden("lv", $in{'lv'});
print &ui_hidden("snap", $in{'snap'});
print &ui_table_start($text{'lv_header'}, "width=100%", 4);

$show_size = $lv->{'cow_size'} || $lv->{'size'};
if (!&can_resize_lv_stat(@stat)) {
	# Current status
	print &ui_table_row($text{'lv_name'}, $lv->{'name'});

	print &ui_table_row($text{'lv_size'}, &nice_size($show_size * 1024));
	}
else {
	# Details for new LV
	if ($stat[2]) {
		print &ui_table_row($text{'lv_name'}, $lv->{'name'},
				    undef, [ "", "valign=top" ]);
		print &ui_hidden("name", $lv->{'name'});
		}
	else {
		print &ui_table_row($text{'lv_name'},
				    &ui_textbox("name", $lv->{'name'}, 30));
		}

	# Thinpool to create in, if any exist
	if (!$in{'lv'} && @thins) {
		print &ui_table_row($text{'lv_thin'},
			&ui_select("thin", "",
				   [ [ "", $text{'lv_nothin'} ],
				     (map { $_->{'name'} } @thins) ]), 3);
		}
	elsif ($lv->{'thin_in'}) {
		print &ui_table_row($text{'lv_thin2'},
			&ui_link("edit_lv.cgi?vg=$in{'vg'}&lv=$lv->{'thin_in'}",
				 $lv->{'thin_in'}));
		}

	if (!$in{'lv'}) {
		# Can show nice size chooser for absolute or relative size
		@pvopts = map { $_->{'name'} }
			      &list_physical_volumes($in{'vg'});
		print &ui_table_row($text{'lv_size'},
			&ui_radio_table("size_mode", 0,
			  [ [ 0, $text{'lv_size0'},
			      &ui_bytesbox("size", $show_size * 1024, 8) ],
			    [ 1, $text{'lv_size1'},
			      &ui_textbox("vgsize", undef, 4)."%" ],
			    [ 2, $text{'lv_size2'},
			      &ui_textbox("freesize", undef, 4)."%" ],
			    [ 3, $text{'lv_size3'},
			      &text('lv_size3a',
			      	&ui_textbox("pvsize", undef, 4)."%",
				&ui_select("pvof", undef, \@pvopts)) ],
			  ]), 3);
		}
	elsif ($lv->{'snap_of'} && $lv->{'thin_in'}) {
		# Snapshot inside a thin pool ... cannot resize
		print &ui_hidden("size_mode", -1);
		}
	else {
		# Check if size is exactly some number of TB, GB or MB, less
		# than 10240
		$div = 1024*1024*1024;
		$size = $show_size*1024;
		$nice = 0;
		while($div >= 1024) {
			$frac = $size*1.0 / $div;
			if ($frac == int($frac) && $frac < 1024*10) {
				$nice = 1;
				last;
				}
			$div /= 1024;
			}
		if ($nice) {
			# Show nicely
			print &ui_table_row($text{'lv_size'},
				&ui_radio_table("size_mode", 0,
				    [ [ 0, $text{'lv_sizesimple'},
					&ui_bytesbox("size", $size, 8) ],
				      [ 2, $text{'lv_sizeallfree'} ] ]));
			}
		else {
			# Show in exactly kB
			print &ui_table_row($text{'lv_size'},
				&ui_radio_table("size_mode", 4,
				    [ [ 4, $text{'lv_sizeabs'},
					&ui_textbox("sizekb", $show_size, 8).
					" kB" ],
				      [ 0, $text{'lv_sizesimple'},
					&ui_bytesbox("size", $size, 8) ],
				      [ 2, $text{'lv_sizeallfree'} ] ]));
			}
		}
	}

# Number of physical extents
print &ui_table_row($text{'lv_petotal'},
	&text('lv_petotals', $vg->{'pe_alloc'}, $vg->{'pe_total'}));

# Extent size
print &ui_table_row($text{'lv_pesize'},
	&nice_size($vg->{'pe_size'}*1024));

if ($in{'lv'} && !$lv->{'thin'}) {
	# Device file and current status
	print &ui_table_row($text{'lv_device'}, "<tt>$lv->{'device'}</tt>");

	print &ui_table_row($text{'lv_status'},
		@stat ? &device_message(@stat) : $text{'lv_notused'});
	}

if ($lv->{'is_snap'}) {
	if ($in{'lv'}) {
		# Show which LV this is a snapshot of
		local $snapof;
		if ($lv->{'snap_of'}) {
			($snapof) = grep { $_->{'name'} eq $lv->{'snap_of'} }
					 @lvs;
			}
		else {
			($snapof) = grep { $_->{'size'} == $lv->{'size'} &&
					   $_->{'has_snap'} } @lvs;
			}
		if ($snapof) {
			$snapsel = &ui_link(
				"edit_lv.cgi?vg=$in{'vg'}&lv=$snapof->{'name'}",
				$snapof->{'name'});
			}
		else {
			$snapsel = "<i>$text{'lv_nosnap'}</i>";
			}
		}
	else {
		# Allow selection of snapshot source
		$snapsel = &ui_select("snapof", undef,
		    [ map { $_->{'name'} } grep { !$_->{'is_snap'} } @lvs ]);
		}
	print &ui_table_row($text{'lv_snapof'}, $snapsel);

	# Show snapshot percentage used
	if ($lv->{'snapusage'}) {
		print &ui_table_row($text{'lv_snapusage'},
			$lv->{'snapusage'}."%");
		}
	}
elsif (!&can_resize_lv_stat(@stat)) {
	# Display current permissons and allocation method
	print &ui_table_row($text{'lv_perm'},
		$text{"lv_perm".$lv->{'perm'}});

	print &ui_table_row($text{'lv_alloc'},
		$text{"lv_alloc".$lv->{'alloc'}});
	}
else {
	# Allow editing of permissons and allocation method
	print &ui_table_row($text{'lv_perm'},
		&ui_radio("perm", $lv->{'perm'},
			  [ [ 'rw', $text{'lv_permrw'} ],
			    [ 'r', $text{'lv_permr'} ] ]));

	print &ui_table_row($text{'lv_alloc'},
		&ui_radio("alloc", $lv->{'alloc'},
			  [ [ 'y', $text{'lv_allocy'} ],
			    [ 'n', $text{'lv_allocn'} ] ]));
	}

if (!$in{'lv'} && !$lv->{'is_snap'}) {
	# Allow selection of striping
	print &ui_table_row($text{'lv_stripe'},
		&ui_opt_textbox("stripe", undef, 4, $text{'lv_nostripe'},
				$text{'lv_stripes2'}), 3);

	# And strip size
	print &ui_table_row($text{'lv_stripesize'},
		&ui_select("stripesize", undef,
			   [ [ undef, $text{'default'} ],
			     map { [ $_, $_." kB" ] }
				 map { 2**$_ } (2 .. 12) ]));
	}
elsif (!$lv->{'is_snap'}) {
	# Show current striping
	print &ui_table_row($text{'lv_stripe'},
		$lv->{'stripes'} > 1 ? &text('lv_stripes', $lv->{'stripes'})
				     : $text{'lv_nostripe'});

	if ($lv->{'stripes'} && $lv->{'stripesize'}) {
		print &ui_table_row($text{'lv_stripesize'},
			&nice_size($lv->{'stripesize'}*1024));
		}
	}

if (!$lv->{'is_snap'}) {
        # Allow selection of readahead sectors
        print &ui_table_row($text{'lv_readahead'},
                &ui_select("readahead", $lv->{'readahead'},
                           [ [ "auto", "Auto" ], [ 0, "None" ],
                             map { [ $_, $_."" ] }
                                 map { 2**$_ } ( 7 .. 16) ]));
        }

# Show free disk space
if (@stat && $stat[2]) {
	($total, $free) = &mount::disk_space($stat[1], $stat[0]);

	print &ui_table_row($text{'lv_freedisk'},
		&nice_size($free*1024));

	print &ui_table_row($text{'lv_free'},
		int($total ? 100 * $free / $total : 0)." %");
	}

# Show extents on PVs
if ($in{'lv'}) {
	@pvinfo = &get_logical_volume_usage($lv);
	if (@pvinfo) {
		foreach $p (@pvinfo) {
			($pv) = grep { $_->{'name'} eq $p->[0] } @pvs;
			push(@pvlist, &ui_link("edit_pv.cgi?vg=$in{'vg'}&pv=$pv->{'name'}",$pv->{'name'})." ".&nice_size($p->[1]*$pv->{'pe_size'}*1024));
			}
		print &ui_table_row($text{'lv_pvs'},
			&ui_grid_table(\@pvlist, 4), 3);
		}
	}

# Show thin pool users
if ($in{'lv'} && $lv->{'thin'}) {
	print &ui_table_row($text{'lv_thinused'},
		&nice_size($lv->{'thin_used'} * 1024));

	print &ui_table_row($text{'lv_thinpercent'},
		$lv->{'thin_percent'}."%");

	@thinc = grep { $_->{'thin_in'} eq $lv->{'name'} } @lvs;
	if (@thinc) {
		foreach $t (@thinc) {
			push(@thinlist, &ui_link("edit_lv.cgi?vg=$in{'vg'}&lv=$t->{'name'}", $t->{'name'})." ".&nice_size($t->{'size'} * 1024));
			}
		print &ui_table_row($text{'lv_thincs'},
			&ui_grid_table(\@thinlist, 4), 3);
		}
	}

print &ui_table_end();
if (!&can_resize_lv_stat(@stat)) {
	# In use - cannot be edited
	print &ui_form_end();
	print "<b>$text{'lv_cannot'}</b><p>\n";
	}
elsif ($stat[2]) {
	# Mounted, but can be resized
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
elsif ($in{'lv'}) {
	if ($lv->{'is_snap'} && &supports_snapshot_rollback()) {
		# Can be resized, deleted or rolled back
			print &ui_form_end([ [ undef, $text{'save'} ],
					   [ 'delete', $text{'delete'} ],
					   [ 'rollback', $text{'lv_snaprollback'} ] ]);
		}
	else {
		# Can be resized or deleted
		print &ui_form_end([ [ undef, $text{'save'} ],
				   [ 'delete', $text{'delete'} ] ]);
		}
	}
else {
	# Can be created
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

if ($in{'lv'} && !$stat[2] && !$lv->{'is_snap'} && !$lv->{'thin'} &&
    $stat[1] ne 'cloudmin' && $stat[1] ne 'iscsi') {
	print &ui_hr();
	print &ui_buttons_start();

	# Show button for creating filesystems
	if ($stat[1]) {
		# Use FS from fstab
		print &ui_buttons_row("mkfs_form.cgi", $text{'lv_mkfs2'},
			      &text('lv_mkfsdesc2', uc($stat[1])),
			      &ui_hidden("dev", $lv->{'device'}).
			      &ui_hidden("fs", $stat[1]).
			      &ui_hidden("lv", $in{'lv'}).
			      &ui_hidden("vg", $in{'vg'}));
		}
	else {
		# Can select FS
		print &ui_buttons_row("mkfs_form.cgi", $text{'lv_mkfs'},
			      $text{'lv_mkfsdesc'},
			      &ui_hidden("dev", $lv->{'device'}).
			      &ui_hidden("lv", $in{'lv'}).
			      &ui_hidden("vg", $in{'vg'}),
			      &ui_select("fs", "ext3",
				[ map { [ $_, $fdisk::text{"fs_".$_}." ($_)" ] }
				      &fdisk::supported_filesystems() ]));
		}

	if (!@stat) {
		# Show button for mounting
		$type = $config{'lasttype_'.$lv->{'device'}} || "ext2";
		print &ui_buttons_row("../mount/edit_mount.cgi",
				      $text{'lv_newmount'},
				      $text{'lv_mountmsg'},
				      &ui_hidden("type", $type).
				      &ui_hidden("newdev", $lv->{'device'}),
				      &ui_textbox("newdir", "", 20));
		}

	print &ui_buttons_end();
	}

# Show PV move form
if ($in{'lv'} && @pvs > 1 && @pvinfo) {
	print &ui_form_start("pvmove.cgi");
	print &ui_hidden("vg", $in{'vg'});
	print &ui_hidden("lv", $in{'lv'});
	print &ui_table_start($text{'lv_moveheader'}, undef, 2);

	@names = map { $_->{'name'} } @pvs;
	print &ui_table_row($text{'lv_pvfrom'},
		&ui_select("from", $pvinfo[0]->[0],
			   [ &unique(map { $_->[0] } @pvinfo) ]));

	($defto) = grep { $_ ne $pvinfo[0]->[0] } @names;
	print &ui_table_row($text{'lv_pvto'},
		&ui_select("to", $defto, \@names));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'lv_moveok'} ] ]);
	}

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return'});

