#!/usr/local/bin/perl
# save_lv.cgi
# Create, update or delete a logical volume

require './lvm-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();

($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
($lv) = grep { $_->{'name'} eq $in{'lv'} } &list_logical_volumes($in{'vg'})
	if ($in{'lv'});

if ($in{'confirm'}) {
	# Delete the logical volume
	&error_setup($text{'lv_err2'});
	$err = &delete_logical_volume($lv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("delete", "lv", $in{'lv'}, $lv);
	&redirect("");
	}
elsif ($in{'delete'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'lv_delete'}, "");
	print "<center><form action=save_lv.cgi>\n";
	print "<input type=hidden name=vg value='$in{'vg'}'>\n";
	print "<input type=hidden name=lv value='$in{'lv'}'>\n";
	print "<b>",&text($lv->{'is_snap'} ? 'lv_rusnap' : 'lv_rusure',
			  "<tt>$lv->{'device'}</tt>"),"</b><p>\n";
	print "<input type=submit name=confirm ",
	      "value='$text{'lv_deleteok'}'>\n";
	print "</center></form>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Validate inputs
	&error_setup($text{'lv_err'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-\_]+$/ || &error($text{'lv_ename'});
	($same) = grep { $_->{'name'} eq $in{'name'} }
		       &list_logical_volumes($in{'vg'});
	$same && (!$in{'lv'} || $in{'lv'} ne $in{'name'}) &&
		&error($text{'lv_esame'});
	$in{'size'} =~ /^\d+$/ || &error($text{'lv_esize'});
	$in{'snap'} || $in{'lv'} || $in{'stripe_def'} ||
		$in{'stripe'} =~ /^[1-9]\d*$/ || &error($text{'lv_estripe'});

	if (!$in{'lv'}) {
		# Just create the logical volume
		$lv->{'vg'} = $in{'vg'};
		$lv->{'name'} = $in{'name'};
		$lv->{'size'} = $in{'size'};
		if ($in{'snap'}) {
			$lv->{'is_snap'} = 1;
			$lv->{'snapof'} = $in{'snapof'};
			}
		else {
			$lv->{'perm'} = $in{'perm'};
			$lv->{'alloc'} = $in{'alloc'};
			$lv->{'stripe'} = $in{'stripe'} if (!$in{'stripe_def'});
			}
		$err = &create_logical_volume($lv);
		&error("<pre>$err</pre>") if ($err);
		&webmin_log("create", "lv", $in{'name'}, $lv);
		}
	elsif ($lv->{'is_snap'}) {
		# Modifying a snapshot
		if ($lv->{'size'} != $in{'size'}) {
			$err = &resize_logical_volume($lv, $in{'size'});
			&error("<pre>$err</pre>") if ($err);
			$lv->{'size'} = $in{'size'};
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
		if ($lv->{'size'} != $in{'size'}) {
			# Is the new size too big?
			local $nblocks = int($in{'size'} / $vg->{'pe_size'})+1;
			local $oblocks = int($lv->{'size'} / $vg->{'pe_size'})+1;
			if ($vg->{'pe_alloc'} - $oblocks + $nblocks > $vg->{'pe_total'}) {
				#&error(&text('lv_toobig', $nblocks, "$vg->{'pe_size'} kB", $vg->{'pe_total'} - $vg->{'pe_alloc'}));
				}

			local $realsize = $nblocks * $vg->{'pe_size'};
			if ($in{'sizeconfirm'}) {
				# Just resize the logical volume
				$err = &resize_logical_volume($lv, $realsize);
				&error("<pre>$err</pre>") if ($err);
				}
			else {
				local $can = &can_resize_filesystem($stat[1]);
				if ($can == 2 ||
				    $can == 1 && $realsize > $lv->{'size'}) {
					# Attempt to resize properly
					$err = &resize_filesystem($lv, $stat[1], $realsize);
					if ($err) {
						$err = &text('resize_fs', $stat[1], "</center><pre>$err</pre><center>");
						}
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
					&ui_print_footer("", $text{'index_return'});
					exit;
					}
				}
			$lv->{'size'} = $realsize;
			}
		if ($lv->{'perm'} ne $in{'perm'} ||
		    $lv->{'alloc'} ne $in{'alloc'}) {
			# Need to change options
			$lv->{'perm'} = $in{'perm'};
			$lv->{'alloc'} = $in{'alloc'};
			$err = &change_logical_volume($lv);
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
	&redirect("");
	}

