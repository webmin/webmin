#!/usr/local/bin/perl
# view_raid.cgi
# Display information about a raid device

require './raid-lib.pl';
&foreign_require("mount", "mount-lib.pl");
&foreign_require("lvm", "lvm-lib.pl");
&ReadParse();

print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&ui_print_header(undef, $text{'view_title'}, "");
$conf = &get_raidtab();
$raid = $conf->[$in{'idx'}];

print "<form action=save_raid.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'view_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'view_device'}</b></td>\n";
print "<td><tt>$raid->{'value'}</tt></td> </tr>\n";

$lvl = &find_value('raid-level', $raid->{'members'});
print "<tr> <td><b>$text{'view_level'}</b></td>\n";
print "<td>",$lvl eq 'linear' ? $text{'linear'}
			      : $text{"raid$lvl"},"</td> </tr>\n";

@st = &device_status($raid->{'value'});
print "<tr> <td><b>$text{'view_status'}</b></td> <td>\n";
print $st[1] eq 'lvm' ? &text('view_lvm', "<tt>$st[0]</tt>") :
      $st[2] ? &text('view_mounted', "<tt>$st[0]</tt>") :
      @st ? &text('view_mount', "<tt>$st[0]</tt>") :
      $raid->{'active'} ? $text{'view_active'} :
			  $text{'view_inactive'};
print "</td> </tr>\n";

if ($raid->{'size'}) {
	print "<tr> <td><b>$text{'view_size'}</b></td>\n";
	print "<td>$raid->{'size'} blocks ",
	      "(",&nice_size($raid->{'size'}*1024),")</td> </tr>\n";
	}
if ($raid->{'resync'}) {
	print "<tr> <td><b>$text{'view_resync'}</b></td>\n";
	print "<td>$raid->{'resync'} \%</td> </tr>\n";
	}

$super = &find_value('persistent-superblock', $raid->{'members'});
print "<tr> <td><b>$text{'view_super'}</b></td>\n";
print "<td>",$super ? $text{'yes'} : $text{'no'},"</td> </tr>\n";

if ($lvl eq '5') {
	$parity = &find_value('parity-algorithm', $raid->{'members'});
	print "<tr> <td><b>$text{'view_parity'}</b></td>\n";
	print "<td>",$parity ? $parity : $text{'default'},"</td> </tr>\n";
	}

$chunk = &find_value('chunk-size', $raid->{'members'});
print "<tr> <td><b>$text{'view_chunk'}</b></td>\n";
print "<td>",$chunk ? "$chunk kB" : $text{'default'},"</td> </tr>\n";

if (ref($raid->{'errors'})) {
	for($i=0; $i<@{$raid->{'errors'}}; $i++) {
		if ($raid->{'errors'}->[$i] ne "U") {
			push(@badlist, $raid->{'devices'}->[$i]);
			}
		}
	if (@badlist) {
		print "<tr> <td><b>$text{'view_errors'}</b></td>\n";
		print "<td><font color=#ff0000>",
			&text('view_bad', scalar(@badlist)),
			"</font></td> </tr>\n";
		}
	}

if ($raid->{'state'}) {
	print "<tr> <td><b>$text{'view_state'}</b></td>\n";
	print "<td>$raid->{'state'}</td> </tr>\n";
	}

if ($raid->{'rebuild'}) {
	print "<tr> <td><b>$text{'view_rebuild'}</b></td>\n";
	print "<td>$raid->{'rebuild'} \%</td> </tr>\n";
	}


# Display partitions in RAID
print "<tr> <td valign=top><b>$text{'view_disks'}</b></td> <td>\n";
foreach $d (&find('device', $raid->{'members'})) {
	if (&find('raid-disk', $d->{'members'}) ||
            &find('parity-disk', $d->{'members'})) {
		local $name = &mount::device_name($d->{'value'});
		print $name,"\n";
		if (!&indevlist($d->{'value'}, $raid->{'devices'}) &&
		    $raid->{'active'}) {
			print "<font color=#ff0000>$text{'view_down'}</font>\n";
			}
		print "<br>\n";
		$rdisks .= "<option value='$d->{'value'}'>$name\n";
		$rdisks_count++;
		}
	}
print "</td> </tr>\n";

# Display spare partitions
foreach $d (&find('device', $raid->{'members'})) {
	if (&find('spare-disk', $d->{'members'})) {
		local $name = &mount::device_name($d->{'value'});
		$sp .= "$name<br>\n";
		$rdisks .= "<option value='$d->{'value'}'>$name\n";
		$rdisks_count++;
		}
	}
if ($sp) {
	print "<tr> <td valign=top><b>$text{'view_spares'}</b></td> <td>\n";
	print $sp,"</td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<p><hr>\n";
print "<table width=100%><tr>\n";

if ($raid_mode eq "raidtools" && !$st[2]) {
	# Only classic raid tools can disable a RAID
	local $act = $raid->{'active'} ? "stop" : "start";
	print "<tr> <td><input type=submit name=$act ",
	      "value='",$text{'view_'.$act},"'></td>\n";
	print "<td>",$text{'view_'.$act.'desc'},"</td> </tr>\n";
	}

if ($raid_mode eq "mdadm") {
	# Only MDADM can add or remove a device (so far)
	$disks = &find_free_partitions([ $raid->{'value'} ], 0, 1);
	if ($disks) {
		print "<tr> <td><input type=submit name=add ",
		      "value='$text{'view_add'}'>\n";
		print "<select name=disk>\n";
		print $disks;
		print "</select></td>\n";
		print "<td>$text{'view_adddesc'}</td> </tr>\n";
		}

	if ($rdisks_count > 1) {
		print "<tr> <td><input type=submit name=remove ",
		      "value='$text{'view_remove'}'>\n";
		print "<select name=rdisk>\n";
		print $rdisks;
		print "</select></td>\n";
		print "<td>$text{'view_removedesc'}</td> </tr>\n";
		}
	}

if ($raid->{'active'} && !$st[2]) {
	# Show buttons for creating filesystems
	print "<tr> <td nowrap><input type=submit name=mkfs ",
	      "value='$text{'view_mkfs2'}'>\n";
	print "<select name=fs>\n";
	foreach $f (&fdisk::supported_filesystems()) {
		printf "<option value=%s %s>%s (%s)\n",
			$f, $stat[1] eq $f ? "selected" : "",
			$fdisk::text{"fs_$f"}, $f;
		}
	print "</select></td>\n";
	print "<td>$text{'view_mkfsdesc'}</td> </tr>\n";
	}

if (!@st) {
	# Show button for mounting filesystem
	print "<tr> <td valign=top>\n";
	print "<input type=submit name=mount ",
	      "value=\"",$text{'view_newmount'},"\">\n";
	print "<input name=newdir size=20></td>\n";
	print "<td>$text{'view_mountmsg'}</td> </tr>\n";

	# Show button for mounting as swap
	print "<tr> <td valign=top>\n";
	print "<input type=submit name=mountswap ",
	      "value=\"",$text{'view_newmount2'},"\"></td>\n";
	print "<td>$text{'view_mountmsg2'}</td> </tr>\n";
	}

if (!$st[2]) {
	print "<tr> <td><input type=submit name=delete value='$text{'view_delete'}'></td>\n";
	print "<td>$text{'view_deletedesc'}</td> </tr>\n";
	}

if ($st[2]) {
	print "<tr> <td colspan=2><b>$text{'view_cannot2'}</b></td> </tr>\n";
	}

print "</tr></table>\n";
print "</form>\n";

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

