#!/usr/local/bin/perl
# copy_part_form.cgi
# Display a form for copying the partitions map of this disk to otthers

require './format-lib.pl';
&ReadParse();
$access{'view'} && &error($text{'ecannot'});
&ui_print_header(undef, "Copy Partition Map", "");
$extwidth = 400;

print "This form allows you to copy the partition map from this disk\n";
print "to others of the same size. This is useful for setting up disks\n";
print "for use as parts of a RAID or mirrored MetaDisk.<p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>Partition</b></td> <td><b>Tag</b></td>\n";
print "<td><b>Extent</b></td> <td><b>Start</b></td> <td><b>End</b></td></tr>\n";
@dlist = &list_disks();
@dinfo = split(/\s+/, $dlist[$in{disk}]); $cyl = $dinfo[2];
@plist = &list_partitions($in{disk});
for($i=0; $i<@plist; $i++) {
	@p = split(/\s+/, $plist[$i]);
	print "<tr $cb> <td>$i</td> <td>$p[0]</td>\n";
	if ($p[3]) {
		printf "<td><img src=images/gap.gif height=10 width=%d>",
			$extwidth*$p[2]/$cyl;
		printf "<img src=images/use.gif height=10 width=%d>",
			$extwidth*($p[3]-$p[2])/$cyl;
		printf "<img src=images/gap.gif height=10 width=%d></td>\n",
			$extwidth*($cyl-$p[3])/$cyl;
		print "<td>$p[2]</td> <td>$p[3]</td> </tr>\n";
		}
	else { print "<td colspan=3><br></td>\n"; }
	print "</tr>\n";
	}
print "</table><p>\n";

# find all disks that are not in use
print "Select the disks to copy this partition map to..<br>\n";
print "<form action=copy_part.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb><td></td> <td><b>Disk Type</b></td> <td><b>Cylinders</b></td>\n";
print "     <td><b>Controller</b></td> <td><b>Target</b></td>\n";
print "     <td><b>Unit</b></td> <td><b>Device</b></td> <td><br></td> </tr>\n";
for($i=0; $i<@dlist; $i++) {
	print "<tr $cb> <td width=20>";
	@d = split(/\s+/, $dlist[$i]);
	undef($err);
	if ($d[2] ne $cyl) { $err = "Different disk size"; }
	elsif ($i == $in{disk}) { $err = "Source disk"; }
	else {
		@plist = split(/\s+/, &list_partitions($i));
		for($j=0; $j<@plist; $j++) {
			$dev = "/dev/dsk/$d[0]s$j";
			if (&device_status($dev)) {
				$err = "Currently in use";
				}
			}
		}

	if (!$err) { print "<input type=checkbox name=disk$i>\n"; }
	else { print "<br>"; }
	print "</td>\n";

	print "<td>$d[1]</td> <td>$d[2]</td>\n";
	$d[0] =~ /c(\d+)t(\d+)d(\d+)/;
	print "<td>$1</td> <td>$2</td> <td>$3</td> <td>$d[0]</td>\n";
	if ($err) { print "<td><font color=#ff0000>$err</font></td> </tr>\n"; }
	else { print "<td><font color=#00ff00>Possible target</font></td> </tr>\n"; }
	if (!$err) { $foundone = 1; }
	}
print "</table><p>\n";
if ($foundone) { print "<input type=submit value=Copy>\n"; }
else { print "No disks are possible targets for copying.\n"; }
print "</form>\n";

&ui_print_footer("", "disk list");

