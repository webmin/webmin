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
	&ui_print_header(undef, $text{'create_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<form action=save_part.cgi><tr $cb><td><table width=100%>\n";
print "<input type=hidden name=disk value=$in{'disk'}>\n";
print "<input type=hidden name=part value=$in{'part'}>\n";
print "<input type=hidden name=new value=$in{'new'}>\n";
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
	print "<input type=hidden name=newpart value=$np>\n";
	print "<input type=hidden name=min value=$min>\n";
	print "<input type=hidden name=max value=$max>\n";

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
print "<input type=hidden name=np value=$np>\n";

print "<tr> <td valign=top><b>$text{'edit_location'}</b></td>\n";
print "<td>",$dinfo->{'device'} =~ /^\/dev\/(s|h)d([a-z])$/ ?
		&text('select_part', $1 eq 's' ? 'SCSI' : 'IDE', uc($2), $np) :
	     $dinfo->{'device'} =~ /rd\/c(\d+)d(\d+)$/ ?
		&text('select_mpart', "$1", "$2", $np) :
	     $dinfo->{'device'} =~ /ida\/c(\d+)d(\d+)$/ ?
		&text('select_cpart', "$1", "$2", $np) :
	     $dinfo->{'device'} =~ /scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
		&text('select_spart', "$1", "$2", "$3", "$4", $np) :
	     $dinfo->{'device'} =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
		&text('select_snewide', "$1", "$2", "$3", "$4", $np) :
		$dinfo->{'device'},"</td>\n";

print "<td><b>$text{'edit_device'}</b></td>\n";
$dev = $dinfo->{'prefix'}.$np;
print "<td>$dev</td> </tr>\n";

print "<tr> <td><b>$text{'edit_type'}</b></td>\n";
if ($pinfo->{'extended'} || $in{'new'} == 3) {
	print "<td>$text{'extended'}</td>\n";
	}
else {
	print "<td nowrap><select name=type>\n";
	foreach $t (sort { &tag_name($a) cmp &tag_name($b) } &list_tags()) {
		printf "<option value=$t %s> %s\n",
			($in{'new'} && $t eq "83" ||
			 !$in{'new'} && $t eq $pinfo->{'type'}) ? "selected"
								: "",
			&tag_name($t);
		}
	print "</select></td>\n";
	}

print "<td><b>$text{'edit_extent'}</b></td>\n";
if ($in{'new'}) {
	print "<td><input name=start size=4 value=$start> - \n";
	print "<input name=end size=4 value=$end>\n";
	}
else {
	print "<td>$pinfo->{'start'} - $pinfo->{'end'}\n";
	}
print $text{'edit_of'}," $dinfo->{'cylinders'}</td> </tr>\n";

print "<tr> <td><b>$text{'edit_status'}</b></td>\n";
if ($pinfo->{'extended'}) {
	foreach $p (@plist) {
		$ecount++ if ($p->{'number'} > 4);
		}
	if ($ecount == 1) {
		print "<td>", $text{'edit_cont1'}, "</td>\n";
		}
	else {
		if ($ecount > 4) {
			print "<td>", &text('edit_cont5', $ecount), "</td>\n";
			}
		else {
			print "<td>", &text('edit_cont234', $ecount), "</td>\n";
			}
		}
	}
else {
	@stat = &device_status($dev);
	if ($in{'new'}) { print "<td>$text{'edit_notexist'}</td>\n"; }
	elsif (@stat) {
		$msg = $stat[2] ? 'edit_mount' : 'edit_umount';
		$msg .= 'vm' if ($stat[1] eq 'swap');
		$msg .= 'raid' if ($stat[1] eq 'raid');
		$msg .= 'lvm' if ($stat[1] eq 'lvm');
		print "<td>",&text($msg, "<tt>$stat[0]</tt>",
				   "<tt>$stat[1]</tt>"),"</td>\n";
		}
	else { print "<td>$text{'edit_notused'}</td>\n"; }
	}

print "<td><b>$text{'edit_size'}</b></td>\n";
if ($in{'new'}) {
	print "<td>$text{'edit_notexist'}</td> </tr>\n";
	}
elsif ($dinfo->{'cylsize'}) {
	print "<td>",&nice_size(($pinfo->{'end'} - $pinfo->{'start'} + 1) * $dinfo->{'cylsize'}),"</td> </tr>\n";
	}
else {
	print "<td>",&text('edit_blocks', $pinfo->{'blocks'}),"</td> </tr>\n";
	}

# Show field for editing filesystem label
print "<tr>\n";
if (($has_e2label || $has_xfs_db) && $pinfo->{'type'} eq '83' && !$in{'new'}) {
	local $label = $in{'new'} ? undef : &get_label($pinfo->{'device'});
	print "<td><b>$text{'edit_label'}</b></td> <td>\n";
	if (@stat) {
		print $label ? "<tt>$label</tt>" : $text{'edit_none'};
		}
	else {
		print "<input name=label size=16 value='$label'>\n";
		}
	print "</td>\n";
	}

# Show current UUID
if ($has_volid && !$in{'new'}) {
	local $volid = &get_volid($pinfo->{'device'});
	print "<td><b>$text{'edit_volid'}</b></td>\n";
	print "<td><tt>$volid</tt></td>\n";
	}
print "</tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value=\"$text{'create'}\">\n";
	}
elsif (@stat && $stat[2]) {
	print "<b>$text{'edit_inuse'}</b><p>\n";
	}
else {
	if (!$pinfo->{'extended'}) {
		print "<input type=submit value=\"$text{'save'}\">\n";
		}
	print "<input name=delete type=submit value=\"$text{'delete'}\">\n";
	}
print "</form><p>\n";

if (!$in{'new'} && !$pinfo->{'extended'}) {
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

