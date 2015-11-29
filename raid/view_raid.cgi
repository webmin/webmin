#!/usr/local/bin/perl
# view_raid.cgi
# Display information about a raid device

require './raid-lib.pl';
&foreign_require("mount");
&foreign_require("lvm");
&ReadParse();

print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&ui_print_header(undef, $text{'view_title'}, "");
$conf = &get_raidtab();
$raid = $conf->[$in{'idx'}];

print &ui_form_start("save_raid.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'view_header'}, undef, 2);

# Device name
print &ui_table_row($text{'view_device'}, "<tt>$raid->{'value'}</tt>");

# UUID
$uuid = &find_value('array-uuid', $raid->{'members'});
print &ui_table_row($text{'view_uuid'}, $uuid);

# RAID level
$lvl = &find_value('raid-level', $raid->{'members'});
print &ui_table_row($text{'view_level'},
	$lvl eq 'linear' ? $text{'linear'} : $text{"raid$lvl"});

# Current status
@st = &device_status($raid->{'value'});
print &ui_table_row($text{'view_status'},
      $st[1] eq 'lvm' ? &text('view_lvm', "<tt>$st[0]</tt>") :
      $st[1] eq 'iscsi' ? &text('view_iscsi', "<tt>$st[0]</tt>") :
      $st[2] ? &text('view_mounted', "<tt>$st[0]</tt>") :
      @st ? &text('view_mount', "<tt>$st[0]</tt>") :
      $raid->{'active'} ? $text{'view_active'} :
			  $text{'view_inactive'});

if ($raid->{'size'}) {
	print &ui_table_row($text{'view_size'},
		&text('view_blocks', $raid->{'size'})." ".
	        "(".&nice_size($raid->{'size'}*1024).")");
	}
if ($raid->{'resync'}) {
	print &ui_table_row($text{'view_resync'},
		$raid->{'resync'} eq 'delayed' ? $text{'view_delayed'}
					       : "$raid->{'resync'} \%");
	}

# Superblock?
$super = &find_value('persistent-superblock', $raid->{'members'});
print &ui_table_row($text{'view_super'},
	$super ? $text{'yes'} : $text{'no'});

# Layout
if (($lvl eq '5') || ($lvl eq '6') || ($lvl eq '10')) {
	$layout = &find_value('parity-algorithm', $raid->{'members'});
	print &ui_table_row($text{'view_parity'}, $layout || $text{'default'});
	}

# Chunk size
$chunk = &find_value('chunk-size', $raid->{'members'});
print &ui_table_row($text{'view_chunk'},
	$chunk ? "$chunk kB" : $text{'default'});

# Current errors
if (ref($raid->{'errors'})) {
	for($i=0; $i<@{$raid->{'errors'}}; $i++) {
		if ($raid->{'errors'}->[$i] ne "U") {
			push(@badlist, $raid->{'devices'}->[$i]);
			}
		}
	if (@badlist) {
		print &ui_table_row($text{'view_errors'},
			"<font color=#ff0000>".
			&text('view_bad', scalar(@badlist)).
			"</font>");
		}
	}

# Current state
if ($raid->{'state'}) {
	print &ui_table_row($text{'view_state'}, $raid->{'state'});
	}

# Rebuild percent
if ($raid->{'rebuild'} ne '') {
	print &ui_table_row($text{'view_rebuild'},
		$raid->{'rebuild'}." \% (".$raid->{'remain'}." min, ".
		int($raid->{'speed'} / 1024)." MB/s)");
	}


# Display partitions in RAID
$rp = undef;
@devs = sort { $a->{'value'} cmp $b->{'value'} }
	     &find('device', $raid->{'members'});
foreach $d (@devs) {
	if (&find('raid-disk', $d->{'members'}) ||
            &find('parity-disk', $d->{'members'})) {
		local $name = &mount::device_name($d->{'value'});
		$rp .= $name."\n";
		if (!&indevlist($d->{'value'}, $raid->{'devices'}) &&
		    $raid->{'active'}) {
			$rp .= "<font color=#ff0000>$text{'view_down'}</font>\n";
			}
		$rp .= "<br>\n";
		push(@rdisks, [ $d->{'value'}, $name ]);
		push(@datadisks, [ $d->{'value'}, $name ]);
		}
	}

$raidcnt = @rdisks;

print &ui_table_row($text{'view_disks'}, $rp);

# Display spare partitions
$sp = undef;
$sparescnt = 0;
$newdisks = @rdisks;
@spares = ( );
foreach $d (@devs) {
	if (&find('spare-disk', $d->{'members'})) {
		local $name = &mount::device_name($d->{'value'});
		$sp .= "$name<br>\n";
		push(@rdisks, [ $d->{'value'}, $name ]);
		push(@sparedisks, [ $d->{'value'}, $name ]);
		$sparescnt++;
		$newdisks++;
		push(@spares, [ "$newdisks", "+ $sparescnt" ]);
		}
	}
if ($sp) {
	print &ui_table_row($text{'view_spares'}, $sp);
	}

# Display spare group, if any
$sg = &find_value("spare-group", $raid->{'members'});
if ($sg) {
	print &ui_table_row($text{'view_sparegroup'}, "<tt>$sg</tt>");
	}

print &ui_table_end();

print &ui_hr();
@grid = ( );

if ($raid_mode eq "raidtools" && !$st[2]) {
	# Only classic raid tools can disable a RAID
	local $act = $raid->{'active'} ? "stop" : "start";
	push(@grid, &ui_submit($text{'view_'.$act}, $act),
		    $text{'view_'.$act.'desc'});
	}

if ($raid_mode eq "mdadm") {
	# Only MDADM can add or remove a device (so far)
	@disks = &find_free_partitions([ $raid->{'value'} ], 0, 1);
	if (@disks) {
		push(@grid, &ui_submit($text{'view_add'}, "add")." ".
			    &ui_select("disk", undef, \@disks),
			    $text{'view_adddesc'});
		}
	if (@rdisks > 1) {
		@rdisks = sort { $a->[0] cmp $b->[0] } @rdisks;
		push(@grid, &ui_submit($text{'view_remove'}, "remove")." ".
			    &ui_select("rdisk", undef, \@rdisks),
			    $text{'view_removedesc'});
		push(@grid, &ui_submit($text{'view_remove_det'}, "remove_det"),
			    $text{'view_remove_detdesc'});
		}
	if ($sparescnt > 0 && &get_mdadm_version() >= 3.3 && &supports_replace()) {
		@rdisks = sort { $a->[0] cmp $b->[0] } @rdisks;
		@spares = sort { $a->[0] cmp $b->[0] } @spares;
                push(@grid, &ui_submit($text{'view_replace'}, "replace")." ".
                            &ui_select("replacedisk", undef, \@datadisks)." with ".
                            &ui_select("replacesparedisk", undef, \@sparedisks),
                            $text{'view_replacedesc'});
		}
	if ($sparescnt > 0 && $lvl != 10) {
		@spares = sort { $a->[0] cmp $b->[0] } @spares;
		push(@grid, &ui_submit($text{'view_grow'}, "grow")." ".
			    &ui_select("ndisk_grow", undef, \@spares),
			    $text{'view_growdesc'});
		if ($lvl == 5 && &get_mdadm_version() >= 3.1) {
			push(@grid, &ui_submit($text{'view_convert_to_raid6'}, "convert_to_raid6")." ".
                        &ui_select("ndisk_convert", undef, \@spares)." ".&ui_hidden("oldcount", $raidcnt),
                        $text{'view_convert_to_raid6desc'});
			}
		}
	if ($lvl == 6 && &get_mdadm_version() >= 3.1) {
		push(@grid, &ui_submit($text{'view_convert_to_raid5'}, "convert_to_raid5")." ".&ui_hidden("oldcount", $raidcnt),
                       	$text{'view_convert_to_raid5desc'});
		}
	}

if ($raid->{'active'} && !$st[2]) {
	# Show buttons for creating filesystems
	$fstype = $st[1] || "ext3";
	push(@grid, &ui_submit($text{'view_mkfs2'}, "mkfs")." ".
	    &ui_select("fs", $fstype,
			[ map { [ $_, $fdisk::text{"fs_".$_}." ($_)" ] }
			      &fdisk::supported_filesystems() ]),
	    $text{'view_mkfsdesc'});
	}

if (!@st) {
	# Show button for mounting filesystem
	push(@grid, &ui_submit($text{'view_newmount'}, "mount")." ".
		    &ui_textbox("newdir", undef, 20),
		    $text{'view_mountmsg'});

	# Show button for mounting as swap
	push(@grid, &ui_submit($text{'view_newmount2'}, "mountswap"),
		    $text{'view_mountmsg2'});
	}

if (!$st[2]) {
	push(@grid, &ui_submit($text{'view_delete'}, "delete"),
		    $text{'view_deletedesc'});
	}

if (@grid) {
	print &ui_grid_table(\@grid, 2, 100, [ "width=20% nowrap" ],
			     "cellpadding=5"),"<p>\n";
	}
if ($st[2]) {
	print "<b>$text{'view_cannot2'}</b><p>\n";
	}
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

# indevlist(device, &list)
sub indevlist
{
local $d;
foreach $d (@{$_[1]}) {
	return 1 if (&same_file($_[0], $d));
	}
return 0;
}

