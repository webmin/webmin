#!/usr/local/bin/perl
# index.cgi
# Display a list of known disks and partitions

require './fdisk-lib.pl';
&error_setup($text{'index_err'});
&check_fdisk();
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1, 0,
	&help_search_link("fdisk", "man", "doc", "howto"));
$extwidth = 250;

$smart = &foreign_installed("smart-status") &&
	 &foreign_available("smart-status");
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'index_disk'}</b></td> ",
      "<td><b>$text{'index_parts'}</b></td> </tr>\n";
foreach $d (&list_disks_partitions()) {
	local $ed = &can_edit_disk($d->{'device'});
	next if (!$ed && !$access{'view'});
	print "<tr $cb> <td valign=top><table>\n";
	print "<tr> <td><b>$text{'index_location'}</b></td> ";
	print "<td>$d->{'desc'}</td>\n";
	print "<tr> <td><b>$text{'index_cylinders'}</b></td> ",
	      "<td>$d->{'cylinders'}</td> </tr>\n";
	if ($d->{'cylsize'}) {
		print "<tr> <td><b>$text{'index_size'}</b></td> ",
		      "<td>",&nice_size($d->{'cylinders'}*$d->{'cylsize'}),
		      "</td> </tr>\n";
		}
	if ($d->{'model'}) {
		print "<tr> <td><b>$text{'index_model'}</b></td> ",
		      "<td>$d->{'model'}</td> </tr>\n";
		}
	if (defined($d->{'scsiid'}) && defined($d->{'controller'})) {
		print "<tr> <td><b>$text{'index_controller'}</b></td> ",
		      "<td>$d->{'controller'}</td> </tr>\n";
		print "<tr> <td><b>$text{'index_scsiid'}</b></td> ",
		      "<td>$d->{'scsiid'}</td> </tr>\n";
		}
	if ($d->{'raid'}) {
		print "<tr> <td><b>$text{'index_raid'}</b></td> ",
		      "<td>$d->{'raid'}</td> </tr>\n";
		}

	# Show links to other modules
	@links = ( );
	if (($d->{'type'} eq 'ide' ||
	    $d->{'type'} eq 'scsi' && $d->{'model'} =~ /ATA/) && $ed) {
		# Display link to IDE params form
		push(@links, "<a href='edit_hdparm.cgi?".
			     "disk=$d->{'index'}'>$text{'index_hdparm'}</a>");
		}
	if ($smart) {
		# Display link to smart module
		push(@links, "<a href='../smart-status/index.cgi?".
			     "drive=$d->{'device'}'>$text{'index_smart'}</a>");
		}
	if (@links) {
		print "<tr> <td colspan=2>",&ui_links_row(\@links),
		      "</td> </tr>\n";
		}

	print "</table></td> <td valign=top nowrap>\n";

	@parts = @{$d->{'parts'}};
	foreach $p (@parts) {
		if ($p->{'end'} > $d->{'cylinders'}-1) {
			$d->{'cylinders'} = $p->{'end'}+1;
			}
		}
	local $extended = 0;
	local $usedpri = 0;
	if (!@parts) {
		print "<b>$text{'index_none'}</b><p>\n";
		}
	else {
		print "<table width=100%> ",
		      "<tr> <td width=10%><b>$text{'index_num'}</b></td> ",
		      "<td width=10%><b>$text{'index_type'}</b></td> ",
                      "<td><b>$text{'index_extent'}</b></td> ",
                      "<td width=10%><b>$text{'index_start'}</b></td> ",
                      "<td width=10%><b>$text{'index_end'}</b></td> ",
                      "<td width=10%><b>$text{'index_use'}</b></td> ",
                      "<td width=10%><b>$text{'index_free'}</b></td> </tr>\n";
		foreach $p (@parts) {
			print "<tr>\n";
			if (!$ed) {
				$lb = $la = "";
				}
			else {
				$lb = "<a href=\"edit_part.cgi?disk=$d->{'index'}&part=$p->{'index'}\">";
				$la = "</a>";
				$extended++ if ($p->{'extended'});
				}
			print "<td width=10%>",$lb,$p->{'number'},$la,"</td>\n";
			$usedpri++ if ($p->{'number'} <= 4);
			print "<td width=10%>",$lb,$p->{'extended'} ?
				$text{'extended'} : &tag_name($p->{'type'}),
			        $la,"</td> <td>\n";
			printf "<img src=images/gap.gif height=10 width=%d>",
				$extwidth*($p->{'start'} - 1) /
				$d->{'cylinders'};
			printf "<img src=images/%s.gif height=10 width=%d>",
				$p->{'extended'} ? "ext" : "use",
				$extwidth*($p->{'end'} - $p->{'start'}) /
				$d->{'cylinders'};
			printf "<img src=images/gap.gif height=10 width=%d>",
			  $extwidth*($d->{'cylinders'} - ($p->{'end'} - 1)) /
				    $d->{'cylinders'};
			print "</td> <td width=10%>$p->{'start'}</td> ",
			      "<td width=10%>$p->{'end'}</td> <td nowrap>\n";
			@stat = &device_status($p->{'device'});
			if ($stat[1] eq 'raid') {
				print "<tt>$stat[0]</tt>\n";
				}
			elsif ($stat[1] eq 'lvm') {
				if (&foreign_available("lvm")) {
					print "<tt><a href='../lvm/'>VG $stat[0]</a></tt>\n";
					}
				else {
					print "<tt>VG $stat[0]</tt>\n";
					}
				}
			elsif ($stat[0] && !&foreign_available("mount")) {
				print "<tt>$stat[0]</tt>\n";
				}
			elsif ($stat[0] && $stat[3] == -1) {
				print "<tt><a href='../mount/edit_mount.cgi?index=$stat[4]&temp=1&return=/$module_name/'>$stat[0]</a></tt>\n";
				}
			elsif ($stat[0]) {
				print "<tt><a href='../mount/edit_mount.cgi?index=$stat[3]&return=/$module_name/'>$stat[0]</a></tt>\n";
				}
			print "</td> <td width=10%>\n";
			if (!$p->{'extended'} && $stat[2] &&
			    &indexof($p->{'type'}, @space_type) >= 0 &&
			    (@space = &disk_space($p->{'device'}, $stat[0])) &&
			    $space[0]) {
				printf "%d %%\n", 100 * $space[1] / $space[0];
				}
			print "</td> </tr>\n";
			}
		print "</table>\n";
		}

	# Show links for adding partitions
	@edlinks = ( );
	if ($usedpri != 4 && $ed) {
		push(@edlinks, "<a href=\"edit_part.cgi?".
		      	       "disk=$d->{'index'}&new=1\">".
		      	       $text{'index_addpri'}."</a>");
		}
	if ($extended && $ed) {
		push(@edlinks, "<a href=\"edit_part.cgi?".
			       "disk=$d->{'index'}&new=2\">".
			       $text{'index_addlog'}."</a>");
		}
	elsif ($usedpri != 4 && $ed) {
		push(@edlinks, "<a href=\"edit_part.cgi?".
			        "disk=$d->{'index'}&new=3\">".
			        $text{'index_addext'}."</a>");
		}
	print &ui_links_row(\@edlinks);
	print "</td> </tr>\n";
	}
print "</table><p>\n";

&ui_print_footer("/", $text{'index'});

