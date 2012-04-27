#!/usr/local/bin/perl
# Show the partitions on a single disk

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'device'}) || &error($text{'disk_ecannot'});
$extwidth = 300;

# Get the disk
@disks = &list_disks_partitions();
($d) = grep { $_->{'device'} eq $in{'device'} } @disks;
$d || &error($text{'disk_egone'});
@parts = @{$d->{'parts'}};
&ui_print_header($d->{'desc'}, $text{'disk_title'}, "", undef,
		 @disks == 1 ? 1 : 0, @disks == 1 ? 1 : 0);

# Work out links to add partitions
foreach $p (@parts) {
	$usedpri++ if ($p->{'number'} <= 4);
	$extended++ if ($p->{'extended'});
	if ($p->{'end'} > $d->{'cylinders'}) {
		$d->{'cylinders'} = $p->{'end'};
		}
	if (!$p->{'extended'} && $stat[2] &&
	    &indexof($p->{'type'}, @space_type) >= 0 &&
	    (@space = &disk_space($p->{'device'}, $stat[0])) &&
	    $space[0]) {
		$p->{'free'} = sprintf "%d %%\n", 100 * $space[1] / $space[0];
		$anyfree++;
		}
	}
if ($usedpri != 4) {
	push(@edlinks, "<a href=\"edit_part.cgi?disk=$d->{'index'}&new=1\">".
		       $text{'index_addpri'}."</a>");
	}
if ($extended) {
	push(@edlinks, "<a href=\"edit_part.cgi?disk=$d->{'index'}&new=2\">".
		       $text{'index_addlog'}."</a>");
	}
elsif ($usedpri != 4 && &supports_extended()) {
	push(@edlinks, "<a href=\"edit_part.cgi?disk=$d->{'index'}&new=3\">".
			$text{'index_addext'}."</a>");
	}

# Show brief disk info
@info = ( );
if ($d->{'cylsize'}) {
	push(@info, &text('disk_dsize', &nice_size($d->{'cylinders'}*$d->{'cylsize'})));
	}
if ($d->{'model'}) {
	push(@info, &text('disk_model', $d->{'model'}));
	}
push(@info, &text('disk_cylinders', $d->{'cylinders'}));
if ($d->{'table'}) {
	push(@info, &text('disk_table', uc($d->{'table'})));
	}
print &ui_links_row(\@info),"<p>\n";

# Show table of partitions, if any
if (@parts) {
	print &ui_links_row(\@edlinks);
	@tds = ( "width=5%", "width=10%", "width=45%", "width=5%", "width=5%", "width=5%", "width=15%", "width=10%" );
	@tds = map { "nowrap $_" } @tds;
	print &ui_columns_start([ $text{'disk_no'},
				  $text{'disk_type'},
				  $text{'disk_extent'},
				  $text{'disk_size'},
				  $text{'disk_start'},
				  $text{'disk_end'},
				  $text{'disk_use'},
				  $anyfree ? ( $text{'disk_free'} ) : ( ),
			         ], 100, 0, \@tds);
	foreach $p (@parts) {
		$url = "edit_part.cgi?disk=$d->{'index'}&part=$p->{'index'}";

		# Create extent images
		$ext = "";
		$ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
			$extwidth*($p->{'start'} - 1) /
			$d->{'cylinders'};
		$ext .= sprintf "<img src=images/%s.gif height=10 width=%d>",
			$p->{'extended'} ? "ext" : "use",
			$extwidth*($p->{'end'} - $p->{'start'}) /
			$d->{'cylinders'};
		$ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
		  $extwidth*($d->{'cylinders'} - ($p->{'end'} - 1)) /
			    $d->{'cylinders'};

		# Work out usage
		@stat = &device_status($p->{'device'});
		$stat = "";
		$statdesc = $stat[0] =~ /^swap/ ? "<i>$text{'disk_vm'}</i>"
						: "<tt>$stat[0]</tt>";
		if ($stat[1] eq 'raid') {
			$stat = $statdesc;
			}
		elsif ($stat[1] eq 'lvm') {
			if (&foreign_available("lvm")) {
				$stat = "<a href='../lvm/'>".
				        "LVM VG $statdesc</a>";
				}
			else {
				$stat = "LVM VG $statdesc";
				}
			}
		elsif ($stat[0] && !&foreign_available("mount")) {
			$stat = $statdesc;
			}
		elsif ($stat[0] && $stat[3] == -1) {
			$stat = "<a href='../mount/edit_mount.cgi?".
				"index=$stat[4]&temp=1&return=/$module_name/'>".
				"$statdesc</a>";
			}
		elsif ($stat[0]) {
			$stat = "<a href='../mount/edit_mount.cgi?".
				"index=$stat[3]&return=/$module_name/'>".
				"$statdesc</a>";
			}

		print &ui_columns_row([
			"<a href='$url'>$p->{'number'}</a>",
			"<a href='$url'>".($p->{'extended'} ?
			  $text{'extended'} : &tag_name($p->{'type'}))."</a>",
			$ext,
			$d->{'cylsize'} ? &nice_size(($p->{'end'} - $p->{'start'} + 1) * $d->{'cylsize'}) : &text('edit_blocks', $p->{'blocks'}),
			$p->{'start'},
			$p->{'end'},
			$stat,
			$anyfree ? ( $p->{'free'} ) : ( ),
			], \@tds);
			
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'disk_none'}</b><p>\n";
	}
print &ui_links_row(\@edlinks);

# Buttons for IDE params and SMART
print &ui_hr();
print &ui_buttons_start();
if (&supports_hdparm($d)) {
	print &ui_buttons_row("edit_hdparm.cgi", $text{'index_hdparm'},
			      $text{'index_hdparmdesc'},
			      &ui_hidden("disk", $d->{'index'}));
	}
if (&supports_smart($d)) {
	print &ui_buttons_row("../smart-status/index.cgi", $text{'index_smart'},
			      $text{'index_smartdesc'},
			      &ui_hidden("drive", $d->{'device'}));
	}
if (&supports_relabel($d)) {
	print &ui_buttons_row("edit_relabel.cgi", $text{'index_relabel'},
			      $text{'index_relabeldesc'},
			      &ui_hidden("device", $d->{'device'}));
	}
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

