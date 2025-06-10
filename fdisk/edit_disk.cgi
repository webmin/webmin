#!/usr/local/bin/perl
# Show the partitions on a single disk

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'device'}) || &error($text{'disk_ecannot'});

# Get the disk
@disks = &list_disks_partitions();
($d) = grep { $_->{'device'} eq $in{'device'} } @disks;
$d || &error($text{'disk_egone'});
@parts = @{$d->{'parts'}};
&ui_print_header($d->{'desc'}, $text{'disk_title'}, "", undef,
		 @disks == 1 ? 1 : 0, @disks == 1 ? 1 : 0);
$caneditpart = $d->{'table'} ne 'gpt' || 
	       ($d->{'table'} eq 'gpt' &&
		&has_command('parted') && $config{'mode'} ne 'fdisk');

# Work out links to add partitions
foreach $p (@parts) {
	$extended++ if ($p->{'extended'});
	$regular++ if (!$p->{'extended'});
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
if ($caneditpart) {
	if ($regular < 4 || $disk->{'table'} ne 'msdos') {
		push(@edlinks,
			&ui_link("edit_part.cgi?disk=$d->{'index'}&new=1",
				 $text{'index_addpri'}));
		}
	if ($extended) {
		push(@edlinks,
			&ui_link("edit_part.cgi?disk=$d->{'index'}&new=2",
			         $text{'index_addlog'}));
		}
	elsif ($regular < 4 && &supports_extended()) {
		push(@edlinks,
			&ui_link("edit_part.cgi?disk=$d->{'index'}&new=3",
				 $text{'index_addext'}));
		}
	}
else {
	$wantsparted = 1;
	}
if ($d->{'table'} eq 'unknown') {
	# Must create a partition table first
	@edlinks = ( $text{'disk_needtable'} );
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
	if ($d->{'table'} eq 'unknown') {
		push(@info, $text{'disk_notable'});
		}
	else {
		push(@info, &text('disk_table', uc($d->{'table'})));
		}
	}
print &ui_links_row(\@info),"<p>\n";

if ($wantsparted) {
	my $label = $config{'mode'} eq 'fdisk' ?
	              'edit_edisk2' : 'edit_edisk';
	print "<p>$text{$label}</p>\n";
	}

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
		$ext1 = int((($p->{'start'} - 1) / $d->{'cylinders'}) * 100) . "%";
		$ext2 = int((($p->{'end'} - $p->{'start'}) / $d->{'cylinders'}) * 100) . "%";
		$ext3 = int((($d->{'cylinders'} - ($p->{'end'} - 1)) / $d->{'cylinders'}) * 100) . "%";
		$ext .= "<img src=images/gap.gif height=10 width='$ext1'>";
		$ext .= sprintf "<img src=images/%s.gif height=10 width='$ext2'>", $p->{'extended'} ? "ext" : "use";
		$ext .= "<img src=images/gap.gif height=10 width='$ext3'>";

		# Work out usage
		@stat = &device_status($p->{'device'});
		$stat = &device_status_link(@stat);

		print &ui_columns_row([
			"<a href='$url'>$p->{'number'}</a>",
			"<a href='$url'>".($p->{'extended'} ?
			  $text{'extended'} : &tag_name($p->{'type'}))."</a>",
			$ext,
			$p->{'size'} ? &nice_size($p->{'size'})
				     : &text('edit_blocks', $p->{'blocks'}),
			$p->{'start'},
			$p->{'end'},
			$stat,
			$anyfree ? ( $p->{'free'} ) : ( ),
			], \@tds);
			
		}
	print &ui_columns_end();
	}
else {
	print "<p>$text{'disk_none'}</p>\n"
		if (!$wantsparted);
	}
print &ui_links_row(\@edlinks);

# Buttons for IDE params and SMART
my $ui_buttons_content = "";
if (&supports_hdparm($d)) {
	$ui_buttons_content .=
	    &ui_buttons_row("edit_hdparm.cgi", $text{'index_hdparm'},
			    $text{'index_hdparmdesc'},
			    &ui_hidden("disk", $d->{'index'}));
	}
if (&supports_smart($d)) {
	$ui_buttons_content .=
	    &ui_buttons_row("../smart-status/index.cgi", $text{'index_smart'},
			    $text{'index_smartdesc'},
			    &ui_hidden("drive", $d->{'device'}));
	}
if (&supports_relabel($d)) {
	if ($d->{'table'} eq 'unknown') {
		$ui_buttons_content .= &ui_buttons_row(
			"edit_relabel.cgi", $text{'index_relabel2'},
			$text{'index_relabeldesc2'},
			&ui_hidden("device", $d->{'device'}));
		}
	else {
		$ui_buttons_content .= &ui_buttons_row(
			"edit_relabel.cgi", $text{'index_relabel'},
			$text{'index_relabeldesc'},
			&ui_hidden("device", $d->{'device'}));
		}
	}
if ($ui_buttons_content) {
	print &ui_hr();
	print &ui_buttons_start();
	print $ui_buttons_content;
	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'index_return'});

