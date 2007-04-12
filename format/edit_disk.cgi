#!/usr/local/bin/perl
# edit_disk.cgi
# Display information about a disk, with links to low-level format,
# repair and other dangerous options

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ui_print_header(undef, "Edit Disk", "");
print "<table width=100%><tr> <td valign=top>\n";
$d = $ARGV[0];

@dlist = &list_disks();
@dinfo = split(/\s+/, $dlist[$d]);
print "<table border width=100%>\n";
print "<tr $tb> <td><b>Disk Details</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>Disk Type:</b></td> <td>$dinfo[1]</td> </tr>\n";
print "<tr> <td><b>Device:</b></td> <td><tt>/dev/dsk/$dinfo[0]</tt></td> </tr>\n";

print "<tr> <td valign=top><b>SCSI:</b></td>\n";
$dinfo[0] =~ /c(\d+)t(\d+)d(\d+)/;
print "<td><table>\n";
print "<tr> <td>Controller</td> <td>$1</td> </tr>\n";
print "<tr> <td>Target</td> <td>$2</td> </tr>\n";
print "<tr> <td>Unit</td> <td>$3</td> </tr></table></td> </tr>\n";

print "<tr> <td valign=top><b>Vendor:</b></td>\n";
@inq = &disk_info($d);
print "<td><table>\n";
print "<tr> <td>Name</td> <td>$inq[0]</td> </tr>\n";
print "<tr> <td>Product</td> <td>$inq[1]</td> </tr>\n";
print "<tr> <td>Revision</td> <td>$inq[2]</td> </tr></table></td> </tr>\n";
print "</table></td></tr></table>\n";

print "</td> <td valign=top>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td colspan=2><b>Disk Tasks</b></td> </tr>\n";
@plist = &list_partitions($d);
for($i=0; $i<@plist; $i++) {
	@stat = &device_status("/dev/dsk/$dinfo[0]s$i");
	if (@stat) { $inuse = 1; }
	if ($stat[2]) { $mounted = 1; }
	}

print "<tr $cb> <form action=format_form.cgi>\n";
print "<td valign=top><b>Format Disk</b><br>\n";
if (!$inuse) {
	print "<input type=hidden name=disk value=$d>\n";
	print "<input type=submit value=\"Format\"></td>\n";
	print "<td>Does a low level format of the disk, permanently erasing\n";
	print "all data. This is only necessary if the disk has not been\n";
	print "formatted by the vendor.</td> </tr>\n";
	}
else {
	print "</td> <td>You cannot format this disk because it contains\n";
	print "filesystems that are in the system mount list.</td> </tr>\n";
	}
print "</form> </tr>\n";

print "<tr $cb> <form action=copy_part_form.cgi>\n";
print "<td valign=top><b>Copy Partitions</b><br>\n";
print "<input type=hidden name=disk value=$d>\n";
print "<input type=submit value=\"Copy\"></td>\n";
print "<td>Copy the partition map from this disk to other disks. This\n";
print "is useful if you have a large number of disks that need the same\n";
print "partition layout, such as for a MetaDisk array.</td> </tr>\n";
print "</form> </tr>\n";

print "</table>\n";

print "</td> </tr></table><p>\n";
&ui_print_footer("", "disk list");

