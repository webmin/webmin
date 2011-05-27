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
	# Extended, cannot change
	print &ui_table_row($text{'edit_type'}, $text{'extended'});
	}
elsif ($pinfo->{'edittype'} || $in{'new'}) {
	# Can change
	print &ui_table_row($text{'edit_type'},
		&ui_select("type",
			   $in{'new'} ? &default_tag() : $pinfo->{'type'},
			   [ map { [ $_, &tag_name($_) ] }
				 (sort { &tag_name($a) cmp &tag_name($b) }
				       &list_tags()) ]));
	}
else {
	# Tool doesn't allow change
	print &ui_table_row($text{'edit_type'},
			    &tag_name($pinfo->{'type'}));
		
	}

# Extent and cylinders
if ($in{'new'}) {
	$ext = &ui_textbox("start", $start, 4)." - ".&ui_textbox("end", $end, 4);
	}
else {
	$ext = "$pinfo->{'start'} - $pinfo->{'end'}";
	}
$ext .= " ".$text{'edit_of'}." ".$dinfo->{'cylinders'};
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
if (($has_e2label || $has_xfs_db) && &supports_label($pinfo) && !$in{'new'}) {
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

# Show field for partition name
if (&supports_name($dinfo)) {
	print &ui_table_row($text{'edit_name'},
			&ui_textbox("name", $pinfo->{'name'}, 20));
	}

# Show current UUID
if ($has_volid && !$in{'new'}) {
	local $volid = &get_volid($pinfo->{'device'});
	print &ui_table_row($text{'edit_volid'}, "<tt>$volid</tt>", 3);
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
	print &ui_hr();
	print &ui_buttons_start();

	if (!@stat || $stat[2] == 0) {
		# Show form for creating filesystem
		local $rt = @stat ? $stat[1] : &conv_type($pinfo->{'type'});
		print &ui_buttons_row("mkfs_form.cgi",
			$text{'edit_mkfs2'}, $text{'edit_mkfsmsg2'},
			&ui_hidden("dev", $dev),
			&ui_select("type", $rt,
                                [ map { [ $_, $fdisk::text{"fs_".$_}." ($_)" ] }
                                      &fdisk::supported_filesystems() ]));
		}

	if (!$in{'new'} && @stat && $stat[2] == 0 && &can_fsck($stat[1])) {
		# Show form to fsck filesystem
		print &ui_buttons_row("fsck_form.cgi",
			$text{'edit_fsck'},&text('edit_fsckmsg', "<tt>fsck</tt>"),
			&ui_hidden("dev", $dev)." ".
			&ui_hidden("type", $stat[1]));
		}

	if (!$in{'new'} && @stat && $stat[2] == 0 && &can_tune($stat[1])) {
		# Show form to tune filesystem
		print &ui_buttons_row("tunefs_form.cgi",
			$text{'edit_tune'}, $text{'edit_tunemsg'},
			&ui_hidden("dev", $dev)." ".
			&ui_hidden("type", $stat[1]));
		}

	@types = &conv_type($pinfo->{'type'});
	if (!$in{'new'} && !@stat && @types) {
		# Show form to mount filesystem
		if ($types[0] eq "swap") {
			# Swap partition
			print &ui_buttons_row("../mount/edit_mount.cgi",
				$text{'edit_newmount2'}, $text{'edit_mountmsg2'},
				&ui_hidden("type", $types[0]));
			}
		else {
			# For some filesystem
			$dirsel = &ui_textbox("newdir", undef, 20);
			if (@types > 1) {
				$dirsel .= $text{'edit_mountas'}." ".
					&ui_select("type", undef, \@types);
				}
			else {
				$dirsel .= &ui_hidden("type", $types[0]);
				}
			print &ui_buttons_row("../mount/edit_mount.cgi",
				$text{'edit_newmount'}, $text{'edit_mountmsg'},
				undef, $dirsel);
			}
		}

	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'index_return'});

