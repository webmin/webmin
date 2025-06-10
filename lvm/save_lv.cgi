#!/usr/local/bin/perl
# save_lv.cgi
# Create, update or delete a logical volume

require './lvm-lib.pl';
&ReadParse();

@lvs = &list_logical_volumes($in{'vg'});
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});
if ($in{'lv'}) {
	($lv) = grep { $_->{'name'} eq $in{'lv'} } @lvs;
	$lv || &error($text{'lv_egone'});
	$oldlv = { %$lv };
	}

if ($in{'confirm'}) {
	# Delete the logical volume
	&error_setup($text{'lv_err2'});
	$err = &delete_logical_volume($lv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("delete", "lv", $in{'lv'}, $lv);
	&redirect("index.cgi?mode=lvs");
	}
elsif ($in{'confirm_rollback'}) {
	# Rollback the Snapshot
	&error_setup($text{'lv_err3'});
	$err = &rollback_snapshot($lv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("rollback", "lv", $in{'lv'}, $lv);
	&redirect("index.cgi?mode=lvs");
	}
elsif ($in{'delete'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'lv_delete'}, "");
	print "<center>\n";
	print &ui_form_start("save_lv.cgi");
	print &ui_hidden("vg", $in{'vg'});
	print &ui_hidden("lv", $in{'lv'});
	print "<b>",&text($lv->{'is_snap'} ? 'lv_rusnap' : 'lv_rusure',
			  "<tt>$lv->{'device'}</tt>"),"</b><p>\n";
	if ($lv->{'thin'}) {
		@thinc = grep { $_->{'thin_in'} eq $lv->{'name'} } @lvs;
		if (@thinc) {
			print "<b>",&text('lv_delthin',
					  scalar(@thinc)),"</b><p>\n";
			}
		}
	print &ui_form_end([ [ 'confirm', $text{'lv_deleteok'} ] ]);
	print "</center>\n";
	&ui_print_footer("index.cgi?mode=lvs", $text{'index_return3'});
	}
elsif ($in{'rollback'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'lv_snaprollback'}, "");
	print "<center>\n";
	print &ui_form_start("save_lv.cgi");
	print &ui_hidden("vg", $in{'vg'});
	print &ui_hidden("lv", $in{'lv'});
	print "<b>",&text('lv_rusnaprb',
			"<tt>$lv->{'device'}</tt>"),"</b><p>\n";
	print &ui_form_end([ [ 'confirm_rollback', $text{'lv_snaprollbackok'} ] ]);
	print "</center>\n";
	&ui_print_footer("index.cgi?mode=lvs", $text{'index_return3'});
	}
else {
	# Validate inputs
	&error_setup($text{'lv_err'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-\_]+$/ || &error($text{'lv_ename'});
	($same) = grep { $_->{'name'} eq $in{'name'} }
		       &list_logical_volumes($in{'vg'});
	$same && (!$in{'lv'} || $in{'lv'} ne $in{'name'}) &&
		&error($text{'lv_esame'});
	if ($in{'size_mode'} == -1) {
		# Cannot change
		$size = undef;
		}
	elsif ($in{'size_mode'} == 0) {
		# Absolute size
		$in{'size'} =~ /^\d+$/ || &error($text{'lv_esize'});
		$size = $in{'size'};
		if (defined($in{'size_units'})) {
			# Convert selected units to kB
			$size *= $in{'size_units'}/1024;
			}
		$sizeof = undef;
		}
	elsif ($in{'size_mode'} == 1) {
		# Size of VG
		$in{'vgsize'} =~ /^\d+$/ &&
			$in{'vgsize'} > 0 &&
			$in{'vgsize'} <= 100 || &error($text{'lv_evgsize'});
		$size = $in{'vgsize'};
		$sizeof = 'VG';
		}
	elsif ($in{'size_mode'} == 2) {
		# Size of free space
		if (!$in{'lv'}) {
			$in{'freesize'} =~ /^\d+$/ &&
				$in{'freesize'} > 0 &&
				$in{'freesize'} <= 100 || &error($text{'lv_efreesize'});
			}
		$size = $in{'freesize'};
		$sizeof = 'FREE';
		}
	elsif ($in{'size_mode'} == 3) {
		# Size of some PV
		$in{'pvsize'} =~ /^\d+$/ &&
			$in{'pvsize'} > 0 &&
			$in{'pvsize'} <= 100 || &error($text{'lv_epvsize'});
		$size = $in{'pvsize'};
		$sizeof = $in{'pvof'};
		}
	elsif ($in{'size_mode'} == 4) {
		# Size in kB
		$in{'sizekb'} =~ /^\d+$/ || &error($text{'lv_esize'});
		$size = $in{'sizekb'};
		$sizeof = undef;
		}
	else {
		&error("Invalid size mode ".$in{'size_mode'});
		}
	$in{'snap'} || $in{'lv'} || $in{'stripe_def'} ||
		$in{'stripe'} =~ /^[1-9]\d*$/ || &error($text{'lv_estripe'});

	if (!$in{'lv'}) {
		# Just create the logical volume
		$lv->{'vg'} = $in{'vg'};
		$lv->{'name'} = $in{'name'};
		$lv->{'size'} = $size;
		$lv->{'size_of'} = $sizeof;
		if ($in{'snap'}) {
			$lv->{'is_snap'} = 1;
			$lv->{'snapof'} = $in{'snapof'};
			}
		else {
			$lv->{'perm'} = $in{'perm'};
			$lv->{'alloc'} = $in{'alloc'};
			$lv->{'stripe'} = $in{'stripe'} if (!$in{'stripe_def'});
			$lv->{'stripesize'} = $in{'stripesize'};
			$lv->{'readahead'} = $in{'readahead'};
			}
		$lv->{'thin_in'} = $in{'thin'};
		$err = &create_logical_volume($lv);
		&error("<pre>$err</pre>") if ($err);
		&webmin_log("create", "lv", $in{'name'}, $lv);
		}
	elsif ($lv->{'is_snap'}) {
		# Modifying a snapshot
		$oldsize = $lv->{'cow_size'} || $lv->{'size'};
		if (defined($size) && $oldsize != $size) {
			$err = &resize_snapshot_volume($lv, $size);
			&error("<pre>$err</pre>") if ($err);
			$lv->{'size'} = $size;
			}
		if ($lv->{'name'} ne $in{'name'}) {
			# Need to rename
			$err = &rename_logical_volume($lv, $in{'name'});
			&error("<pre>$err</pre>") if ($err);
			$lv->{'name'} = $in{'name'};
			}
		}
	else {
		# Modifying the logical volume
		@stat = &device_status($lv->{'device'});
		if ($lv->{'size'} != $size) {
			# Is the new size too big?
			local $nblocks = &round_up(
				$size * 1.0 / $vg->{'pe_size'});
			local $oblocks = &round_up(
				$lv->{'size'} * 1.0 / $vg->{'pe_size'});
			if ($vg->{'pe_alloc'} - $oblocks + $nblocks > $vg->{'pe_total'}) {
				#&error(&text('lv_toobig', $nblocks, "$vg->{'pe_size'} kB", $vg->{'pe_total'} - $vg->{'pe_alloc'}));
				}

			local $realsize = $nblocks * $vg->{'pe_size'};

			if ($in{'size_mode'} == 2) {
				# Calculate free VG space and add current LV size to get the actual new LV size
				$realsize = ($vg->{'pe_total'}*$vg->{'pe_size'})-($vg->{'pe_alloc'}*$vg->{'pe_size'})+$lv->{'size'};
				}

			if ($in{'sizeconfirm'}) {
				# Just resize the logical volume
				$err = &resize_logical_volume($lv, $realsize);
				&error("<pre>$err</pre>") if ($err);
				}
			else {
				local $can = &can_resize_lv_stat(@stat);
				if (($can == 2 ||
				     $can == 1 && $realsize > $lv->{'size'}) &&
				    $stat[1]) {
					# Attempt to resize FS properly
					$err = &resize_filesystem($lv, $stat[1],
								  $realsize);
					if ($err) {
						$err = &text('resize_fs',
							$stat[1],
							"</center><pre>$err".
							 "</pre><center>");
						}
					}
				elsif ($stat[2]) {
					# Cannot resize while mounted
					&error($can == 1 ? 
						$text{'resize_emounted2'} :
						$text{'resize_emounted'});
					}
				else {
					# Cannot resize .. ask for confirmation
					$err = @stat && $stat[1] ne '*' &&
					       $stat[1] ne 'auto' ?
						&text('resize_mesg', $stat[1]) :
						$text{'resize_mesg2'};
					}
				if ($err) {
					&ui_print_header(undef, $text{'resize_title'}, "");
					print "<center><form action=save_lv.cgi>\n";
					foreach $i (keys %in) {
						print "<input type=hidden name=$i value='$in{$i}'>\n";
						}
					print "<b>$err</b> <p>\n";
					print "<input type=submit name=sizeconfirm value='$text{'resize_ok'}'>\n";
					print "</form></center>\n";
					&ui_print_footer("index.cgi?mode=lvs", $text{'index_return3'});
					exit;
					}
				}
			$lv->{'size'} = $realsize;
			}
		if ($lv->{'perm'} ne $in{'perm'} ||
		    $lv->{'alloc'} ne $in{'alloc'} ||
		    $lv->{'readahead'} ne $in{'readahead'}) {
			# Need to change options
			$lv->{'perm'} = $in{'perm'};
			$lv->{'alloc'} = $in{'alloc'};
			$lv->{'readahead'} = $in{'readahead'};
			$err = &change_logical_volume($lv, $oldlv);
			&error("<pre>$err</pre>") if ($err);
			}
		if ($lv->{'name'} ne $in{'name'}) {
			# Need to rename
			$err = &rename_logical_volume($lv, $in{'name'});
			&error("<pre>$err</pre>") if ($err);
			$lv->{'name'} = $in{'name'};
			}
		&webmin_log("modify", "lv", $in{'lv'}, $lv);
		}
	&redirect("index.cgi?mode=lvs");
	}

sub round_up
{
local ($n) = @_;
if (int($n) != $n) {
	return int($n)+1;
	}
return $n;
}
