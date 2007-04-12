#!/usr/local/bin/perl
# Display a form for editing an existing logical volume

require './lvm-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
@lvs = &list_logical_volumes($in{'vg'});

$vgdesc = &text('lv_vg', $vg->{'name'});
if ($in{'lv'}) {
	($lv) = grep { $_->{'name'} eq $in{'lv'} } @lvs;
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
	}

print "<form action=save_lv.cgi>\n";
print "<input type=hidden name=vg value='$in{'vg'}'>\n";
print "<input type=hidden name=lv value='$in{'lv'}'>\n";
print "<input type=hidden name=snap value='$in{'snap'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'lv_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($stat[2]) {
	print "<tr> <td><b>$text{'lv_name'}</b></td>\n";
	print "<td>$lv->{'name'}</td>\n";

	print "<td><b>$text{'lv_size'}</b></td>\n";
	print "<td>",&nice_size($lv->{'size'}*1024),"</td> </tr>\n";
	}
else {
	print "<tr> <td><b>$text{'lv_name'}</b></td>\n";
	print "<td><input name=name size=15 value='$lv->{'name'}'></td>\n";

	print "<td><b>$text{'lv_size'}</b></td>\n";
	print "<td><input name=size size=8 value='$lv->{'size'}'> kB</td> </tr>\n";
	}

print "<tr> <td><b>$text{'lv_petotal'}</b></td>\n";
print "<td>",&text('lv_petotals', $vg->{'pe_alloc'}, $vg->{'pe_total'}),
      "</td>\n";

print "<td><b>$text{'lv_pesize'}</b></td>\n";
print "<td>$vg->{'pe_size'} kB</td> </tr>\n";

if ($in{'lv'}) {
	print "<tr> <td><b>$text{'lv_device'}</b></td>\n";
	print "<td><tt>$lv->{'device'}</tt></td>\n";

	print "<td><b>$text{'lv_status'}</b></td> <td>\n";
	if (!@stat) {
		print $text{'lv_notused'};
		}
	else {
		$msg = &device_message(@stat);
		print $msg;
		}
	print "</td> </tr>\n";
	}

if ($lv->{'is_snap'}) {
	print "<tr> <td><b>$text{'lv_snapof'}</b></td> <td>\n";
	if ($in{'lv'}) {
		# Show which LV this is a snapshot of
		local @snapof = grep { $_->{'size'} == $lv->{'size'} &&
				       $_->{'has_snap'} } @lvs;
		if (@snapof == 1) {
			print "<tt>$snapof[0]->{'name'}</tt>";
			}
		else {
			print "<i>$text{'lv_nosnap'}</i>";
			}
		}
	else {
		# Allow selection of snapshot source
		print "<select name=snapof>\n";
		foreach $l (@lvs) {
			print "<option>$l->{'name'}\n" if (!$l->{'is_snap'});
			}
		print "</select>\n";
		}
	print "</td> </tr>\n";
	}
elsif ($stat[2]) {
	# Display current permissons and allocation method
	print "<tr> <td><b>$text{'lv_perm'}</b></td>\n";
	print "<td>",$text{"lv_perm".$lv->{'perm'}},"</td>\n";

	print "<td><b>$text{'lv_alloc'}</b></td>\n";
	print "<td>",$text{"lv_alloc".$lv->{'alloc'}},"</td> </tr>\n";
	}
else {
	# Allow editing of permissons and allocation method
	print "<tr> <td><b>$text{'lv_perm'}</b></td>\n";
	printf "<td><input type=radio name=perm value=rw %s> %s\n",
		$lv->{'perm'} eq 'rw' ? 'checked' : '', $text{'lv_permrw'};
	printf "<input type=radio name=perm value=r %s> %s</td>\n",
		$lv->{'perm'} eq 'r' ? 'checked' : '', $text{'lv_permr'};

	print "<td><b>$text{'lv_alloc'}</b></td>\n";
	printf "<td><input type=radio name=alloc value=y %s> %s\n",
		$lv->{'alloc'} eq 'y' ? 'checked' : '', $text{'lv_allocy'};
	printf "<input type=radio name=alloc value=n %s> %s</td> </tr>\n",
		$lv->{'alloc'} eq 'n' ? 'checked' : '', $text{'lv_allocn'};
	}

if (!$in{'lv'} && !$lv->{'is_snap'}) {
	# Allow selection of striping
	print "<tr> <td><b>$text{'lv_stripe'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=stripe_def value=1 checked> %s\n",
		$text{'lv_nostripe'};
	print "<input type=radio name=stripe_def value=0>\n";
	print &text('lv_stripes', "<input name=stripe size=4>"),
	      "</td> </tr>\n";
	}
elsif (!$lv->{'is_snap'}) {
	# Show current striping
	print "<tr> <td><b>$text{'lv_stripe'}</b></td> <td colspan=3>\n";
	if ($lv->{'stripes'} > 1) {
		print &text('lv_stripes', $lv->{'stripes'});
		}
	else {
		print $text{'lv_nostripe'};
		}
	print "</td> </tr>\n";
	}

# Show free disk space
if (@stat && $stat[2]) {
	($total, $free) = &mount::disk_space($stat[1], $stat[0]);

	print "<tr> <td><b>$text{'lv_freedisk'}</b></td> <td>\n";
	print &nice_size($free*1024),"</td>\n";

	print "<td><b>$text{'lv_free'}</b></td> <td>\n";
	printf "%d %%\n", $total ? 100 * $free / $total : 0;
	print "</td> </tr>\n";
	}

# Show extents on PVs
if ($in{'lv'}) {
	@pvinfo = &get_logical_volume_usage($lv);
	if (@pvinfo) {
		@pvs = &list_physical_volumes($in{'vg'});
		print "<tr> <td><b>$text{'lv_pvs'}</b></td> <td colspan=3>\n";
		foreach $p (@pvinfo) {
			print " , \n" if ($p ne $pvinfo[0]);
			($pv) = grep { $_->{'name'} eq $p->[0] } @pvs;
			print "<a href='edit_pv.cgi?vg=$in{'vg'}&pv=$pv->{'name'}'>$pv->{'name'}</a> ";
			print &nice_size($p->[1]*$pv->{'pe_size'}*1024),"\n";
			}
		print "</td> </tr>\n";
		}
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($stat[2]) {
	print "<td><b>$text{'lv_cannot'}</b></td>\n";
	}
elsif ($in{'lv'}) {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
print "</tr></table></form>\n";

if ($in{'lv'} && !$stat[2] && !$lv->{'is_snap'}) {
	# Show button for creating filesystems
	print "<hr>\n";
	print "<table width=100%><tr>\n";
	print "<form action=mkfs_form.cgi>\n";
	print "<input type=hidden name=dev value='$lv->{'device'}'>\n";
	print "<td nowrap><input type=submit value='$text{'lv_mkfs'}'>\n";
	print "<select name=fs>\n";
	foreach $f (&fdisk::supported_filesystems()) {
		printf "<option value=%s %s>%s (%s)\n",
			$f, $stat[1] eq $f ? "selected" : "",
			$fdisk::text{"fs_$f"}, $f;
		}
	print "</select></td>\n";
	print "<td>$text{'lv_mkfsdesc'}</td>\n";
	print "</form></tr>\n";

	if (!@stat) {
		# Show button for mounting
		$type = $config{'lasttype_'.$lv->{'device'}} || "ext2";
		print "<tr> <form action=../mount/edit_mount.cgi>\n";
		print "<input type=hidden name=type value=$type>\n";
		print "<input type=hidden name=newdev value=$lv->{'device'}>\n";
		print "<td valign=top>\n";
		print "<input type=submit value=\"",$text{'lv_newmount'},"\">\n";
		print "<input name=newdir size=20></td>\n";
		print "<td>$text{'lv_mountmsg'}</td> </tr>\n";
		print "</form> </tr>\n";
		}

	print "</table>\n";
	}

&ui_print_footer("", $text{'index_return'});

