#!/usr/local/bin/perl
# index.cgi
# Display a list of known disks and partitions

require './format-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("format", "man"));
$extwidth = 250;

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'index_disk'}</b></td> ",
      "<td><b>$text{'index_parts'}</b></td> </tr>\n";
@dlist = &list_disks();
$mountcan = &foreign_available("mount");
for($i=0; $i<@dlist; $i++) {
	$dl = $dlist[$i];
	next if (!&can_edit_disk($dl->{'device'}));
	print "<tr $cb> <td valign=top><table>\n";
	print "<tr> <td><b>$text{'index_location'}</b></td> ";
	print "<td>$dl->{'desc'}</td> </tr>\n";
	print "<tr> <td><b>$text{'index_cyl'}</b></td>\n";
	print "<td>$dl->{'cyl'}</td> </tr>\n";
	print "<tr> <td><b>$text{'index_model'}</b></td> ";
	print "<td>",$dl->{'type'} ? $dl->{'type'} : $text{'index_unknown'},
	      "</td> </tr>\n";
	print "</table></td> <td valign=top>\n";
	if (!$dl->{'device'}) {
		# Drive type unknown..
		print "<b>$text{'index_unknown2'}</b>\n";
		}
	elsif (@parts = &list_partitions($dl->{'device'})) {
		# Known and formatted..
		print "<table width=100%>\n";
		print "<tr> <td><b>$text{'index_no'}</b></td> ",
		      "<td><b>$text{'index_type'}</b></td> ",
		      "<td><b>$text{'index_extent'}</b></td> ",
		      "<td><b>$text{'index_start'}</b></td> ",
		      "<td><b>$text{'index_end'}</b></td> ",
		      "<td><b>$text{'index_use'}</b></td> ",
		      "<td><b>$text{'index_free'}</b></td> </tr>\n";
		for($j=0; $j<@parts; $j++) {
			$p = $parts[$j];
			print "<tr> <td>\n";
			if ($access{'view'}) {
				print $j;
				}
			else {
				print "<a href=\"edit_part.cgi?$i+$j\">$j</a>";
				}
			print "</td> <td>$p->{'tag'}</td> <td>\n";
			if ($p->{'end'} != 0) {
				printf
				  "<img src=images/gap.gif height=10 width=%d>",
				  $extwidth*$p->{'start'}/$dl->{'cyl'};
				printf
				  "<img src=images/use.gif height=10 width=%d>",
				  $extwidth*($p->{'end'}-$p->{'start'})/
				  $dl->{'cyl'};
				printf
				  "<img src=images/gap.gif height=10 width=%d>",
				  $extwidth*($dl->{'cyl'}-$p->{'end'})/
				  $dl->{'cyl'};
				print "</td> <td>$p->{'start'}</td> ",
				      "<td>$p->{'end'}</td> <td>\n";
				@stat = &device_status($p->{'device'});
				if ($stat[1] =~ /^meta/) {
					print "MetaDisk\n";
					}
				elsif (!$mountcan) {
					print "<tt>$stat[0]</tt>\n";
					}
				elsif ($stat[0] && $stat[3] == -1) {
					print "<tt><a href=/mount/edit_mount.cgi?index=$stat[4]&temp=1&return=/$module_name/>$stat[0]</a></tt>\n";
					}
				elsif ($stat[0]) {
					print "<tt><a href=/mount/edit_mount.cgi?index=$stat[3]&return=/$module_name/>$stat[0]</a></tt>\n";
					}
				print "</td> <td>\n";
				if ($stat[0] ne 'swap' &&
				    (@space = &disk_space($p->{'device'})) &&
				    $space[0]) {
					printf "%d %%\n",
					       100 * $space[1] / $space[0];
					}
				print "</td> </tr>\n";
				}
			else { print "<td colspan=5></td>\n"; }
			}
		print "</table>\n";
		}
	else {
		# Disk is not formatted.. 
		print "<b>$text{'index_format'}</b>\n";
		}
	print "</td> </tr>\n";
	}
print "</table><p>\n";

&ui_print_footer("/", $text{'index'});

