#!/usr/local/bin/perl
# edit_part.cgi
# Edit an existing partition, or create a new one

require './fdisk-lib.pl';
&ReadParse();
@dlist = &list_disks_partitions();
$dinfo = $dlist[$in{'disk'}];
&can_edit_disk($dinfo->{'device'}) ||
	&error($text{'edit_ecannot'});
if ($in{'new'}) {
	&ui_print_header($dinfo->{'desc'}, $text{'create_title'}, "");
	}
else {
	&ui_print_header($dinfo->{'desc'}, $text{'edit_title'}, "");
	}

print &ui_form_start("save_part.cgi");
print &ui_table_start($text{'edit_details'}, "width=100%", 4);
print &ui_hidden("disk", $in{'disk'});
print &ui_hidden("part", $in{'part'});
print &ui_hidden("new", $in{'new'});

# Work out the start and end for the new partition
@plist = @{$dinfo->{'parts'}};
if ($in{'new'}) {
	if ($in{'new'} == 1 || $in{'new'} == 3) {
		# Adding a new primary or extended partition
		$np = 1;
		for($i=0; $i<@plist; $i++) {
			if ($plist[$i]->{'number'} == $np) { $np++; }
			push(@start, $plist[$i]->{'start'});
			push(@end, $plist[$i]->{'end'});
			}
		$min = 1;
		$max = $dinfo->{'cylinders'};
		}
	else {
		# Adding a new logical partition (inside the extended partition)
		$np = 5;
		for($i=0; $i<@plist; $i++) {
			if ($plist[$i]->{'number'} == $np) { $np++; }
			if ($plist[$i]->{'extended'}) {
				$min = $plist[$i]->{'start'};
				$max = $plist[$i]->{'end'};
				}
			else {
				push(@start, $plist[$i]->{'start'});
				push(@end, $plist[$i]->{'end'});
				}
			}
		}
	print &ui_hidden("newpart", $np);
	print &ui_hidden("min", $min);
	print &ui_hidden("max", $max);

	# find a gap in the partition map
	for($start=$min; $start<=$max; $start++) {
		$found = 1;
		for($i=0; $i<@start; $i++) {
			if ($start >= $start[$i] && $start <= $end[$i]) {
				$found = 0;
				last;
				}
			}
		if ($found) { last; }
		}
	if ($found) {
		# starting place found.. find the end
		$found = 0;
		for($end=$start; $end<=$max; $end++) {
			for($i=0; $i<@start; $i++) {
				if ($end >= $start[$i] && $end <= $end[$i]) {
					$found = 1;
					last;
					}
				}
			if ($found) { last; }
			}
		$end--;
		}
	else {
		# no place for new partition!
		$start = $end = 0;
		}
	}
else { 
	# Just editing an existing partition
	$pinfo = $plist[$in{'part'}];
	$np = $pinfo->{'number'};
	}
print &ui_hidden("np", $np);

# Describe partition
print &ui_table_row($text{'edit_location'},
	     $dinfo->{'device'} =~ /^\/dev\/(s|h)d([a-z])$/ ?
		&text('select_part', $1 eq 's' ? 'SCSI' : 'IDE', uc($2), $np) :
	     $dinfo->{'device'} =~ /rd\/c(\d+)d(\d+)$/ ?
		&text('select_mpart', "$1", "$2", $np) :
	     $dinfo->{'device'} =~ /ida\/c(\d+)d(\d+)$/ ?
		&text('select_cpart', "$1", "$2", $np) :
	     $dinfo->{'device'} =~ /scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
		&text('select_spart', "$1", "$2", "$3", "$4", $np) :
	     $dinfo->{'device'} =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
		&text('select_snewide', "$1", "$2", "$3", "$4", $np) :
		$dinfo->{'device'});

# Device name
$dev = $dinfo->{'prefix'}.$np;
print &ui_table_row($text{'edit_device'}, $dev);

# Partition type
if ($pinfo->{'extended'} || $in{'new'} == 3) {
	print &ui_table_row($text{'edit_type'}, $text{'extended'});
	}
else {
	print &ui_table_row($text{'edit_type'},
		&ui_select("type", $in{'new'} ? 83 : $pinfo->{'type'},
			   [ map { [ $_, &tag_name($_) ] }
				 (sort { &tag_name($a) cmp &tag_name($b) }
				       &list_tags()) ]));
	}

# Extent and cylinders
if ($in{'new'}) {
	$ext = &ui_textbox("start", $start, 4)." - ".&ui_textbox("end", $end, 4);
	}
else {
	$ext = "$pinfo->{'start'} - $pinfo->{'end'}";
	}
$ext .= " ".$text{'edit_of'}." $dinfo->{'cylinders'};
print &ui_table_row($text{'edit_extent'}, $ext);

# Current status
if ($pinfo->{'extended'}) {
	foreach $p (@plist) {
		$ecount++ if ($p->{'number'} > 4);
		}
	if ($ecount == 1) {
		$stat = $text{'edit_cont1'};
		}
	else {
		if ($ecount > 4) {
			$stat = &text('edit_cont5', $ecount);
			}
		else {
			$stat = &text('edit_cont234', $ecount);
			}
		}
	}
elsif (!$in{'new'}) {
	@stat = &device_status($dev);
	if (@stat) {
		$msg = $stat[2] ? 'edit_mount' : 'edit_umount';
		$msg .= 'vm' if ($stat[1] eq 'swap');
		$msg .= 'raid' if ($stat[1] eq 'raid');
		$msg .= 'lvm' if ($stat[1] eq 'lvm');
		$stat = &text($msg, "<tt>$stat[0]</tt>",
				    "<tt>$stat[1]</tt>");
		}
	else {
		$stat = $text{'edit_notused'};
		}
	}
if ($stat) {
	print &ui_table_row($text{'edit_status'}, $stat);
	}

# Partition size
if (!$in{'new'}) {
	print &ui_table_row($text{'edit_size'},
		$dinfo->{'cylsize'} ? &nice_size(($pinfo->{'end'} - $pinfo->{'start'} + 1) * $dinfo->{'cylsize'}) : &text('edit_blocks', $pinfo->{'blocks'}));
	}

# Show field for editing filesystem label
if (($has_e2label || $has_xfs_db) && $pinfo->{'type'} eq '83' && !$in{'new'}) {
	local $label = $in{'new'} ? undef : &get_label($pinfo->{'device'});
	if (@stat) {
		print &ui_table_row($text{'edit_label'},
			$label ? "<tt>$label</tt>" : $text{'edit_none'});
		}
	else {
		print &ui_table_row($text{'edit_label'},
			&ui_textbox("label", $label, 16));
		}
	}

# Show current UUID
if ($has_volid && !$in{'new'}) {
	local $volid = &get_volid($pinfo->{'device'});
	print &ui_table_row($text{'edit_volid'}, "<tt>$volid</tt>");
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
elsif (@stat && $stat[2]) {
	print &ui_form_end();
	print "<b>$text{'edit_inuse'}</b><p>\n";
	}
else {
	print &ui_form_end([ $pinfo->{'extended'} ? ( ) :
				( [ undef, $text{'save'} ] ),
			     [ 'delete', $text{'delete'} ] ]);
	}

if (!$in{'new'} && !$pinfo->{'extended'}) {
	print "<hr>\n";

	if (!@stat || $stat[2] == 0) {
		# Show form for creating filesystem
		print "<hr><table width=100%>\n" if (!$donehead++);
		print "<tr> <form action=mkfs_form.cgi>\n";
		print "<input type=hidden name=dev value=$dev>\n";
		print "<td nowrap><input type=submit value='$text{'edit_mkfs2'}'>\n";
		print "<select name=type>\n";
		local $rt = @stat ? $stat[1] : &conv_type($pinfo->{'type'});
		foreach $f (&supported_filesystems()) {
			printf "<option value=%s %s>%s (%s)\n",
				$f, $rt eq $f ? "selected" : "",
				$text{"fs_$f"}, $f;
			}
		print "</select></td>\n";
		print "<td>$text{'edit_mkfsmsg2'}</td> </form></tr>\n";
		}

	if (!$in{'new'} && @stat && $stat[2] == 0 && &can_fsck($stat[1])) {
		# Show form to fsck filesystem
		print "<hr><table width=100%>\n" if (!$donehead++);
		print "<tr> <form action=fsck_form.cgi>\n";
		print "<td valign=top>\n";
		print "<input type=hidden name=dev value=$dev>\n";
		print "<input type=hidden name=type value=$stat[1]>\n";
		print "<input type=submit value=\"$text{'edit_fsck'}\"></td>\n";
		print "<td>",&text('edit_fsckmsg', "<tt>fsck</tt>"),"</td>\n";
		print "</form> </tr>\n";
		}

	if (!$in{'new'} && @stat && $stat[2] == 0 && &can_tune($stat[1])) {
		# Show form to tune filesystem
		print "<hr><table width=100%>\n" if (!$donehead++);
		print "<tr> <form action=tunefs_form.cgi>\n";
		print "<td valign=top>\n";
		print "<input type=hidden name=dev value=$dev>\n";
		print "<input type=hidden name=type value=$stat[1]>\n";
		print "<input type=submit value=\"", $text{'edit_tune'}, "\"></td>\n";
		print "<td>$text{'edit_tunemsg'}</td> </tr>\n";
		print "</form> </tr>\n";
		}

	@types = &conv_type($pinfo->{'type'});
	if (!$in{'new'} && !@stat && @types) {
		# Show form to mount filesystem
		print "<hr><table width=100%>\n" if (!$donehead++);
		print "<tr> <form action=../mount/edit_mount.cgi>\n";
		print "<input type=hidden name=newdev value=$dev>\n";
		print "<td valign=top>\n";
		if ($types[0] eq "swap") {
			# Swap partition
			print "<input type=submit value=\"$text{'edit_newmount2'}\">\n";
			print "</td>\n";
			print &ui_hidden("type", $types[0]);
			print "<td>$text{'edit_mountmsg2'}</td> </tr>\n";
			}
		else {
			# For some filesystem
			print "<input type=submit value=\"$text{'edit_newmount'}\">\n";
			print "<input name=newdir size=20>\n";
			if (@types > 1) {
				print "$text{'edit_mountas'} <select name=type>\n";
				foreach $t (@types) {
					print "<option>$t\n";
					}
				print "</select>\n";
				}
			else {
				print &ui_hidden("type", $types[0]);
				}
			print "</td>\n";
			print "<td>$text{'edit_mountmsg'}</td> </tr>\n";
			}
		print "</form> </tr>\n";
		}

	print "</table><p>\n" if ($donehead);
	}

&ui_print_footer("", $text{'index_return'});

