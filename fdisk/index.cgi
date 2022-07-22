#!/usr/local/bin/perl
# index.cgi
# Display a list of known disks and partitions

require './fdisk-lib.pl';
&error_setup($text{'index_err'});
&check_fdisk();

# Work out which disks are accessible
@disks = &list_disks_partitions();
@disks = grep { $access{'view'} || &can_edit_disk($_->{'device'}) } @disks;
$pdesc = $has_parted ? $text{'index_parted'} : $text{'index_fdisk'};
&ui_print_header($pdesc, $module_info{'desc'}, "", undef, 1, 1, 0,
	&help_search_link("fdisk", "man", "doc", "howto"));
$extwidth = 250;

# Check for critical commands
if ($has_parted) {
	&has_command("parted") ||
		&ui_print_endpage(&text('index_ecmd', '<tt>parted</tt>'));
	}
else {
	&has_command("fdisk") ||
		&ui_print_endpage(&text('index_ecmd', '<tt>fdisk</tt>'));
	}

# Show a table of just disks
@disks = sort { $a->{'device'} cmp $b->{'device'} } @disks;
if (@disks) {
	($hasctrl) = grep { defined($d->{'scsiid'}) ||
			    defined($d->{'controller'}) ||
			    $d->{'raid'} } @disks;
	print &ui_columns_start([ $text{'index_dname'},
				  $text{'index_dsize'},
				  $text{'index_dmodel'},
				  $text{'index_dparts'},
				  $hasctrl ? ( $text{'index_dctrl'} ) : ( ),
				  $text{'index_dacts'} ]);
	foreach $d (@disks) {
		$ed = &can_edit_disk($d->{'device'});
		$smart = &supports_smart($d);
		@links = ( );
		@ctrl = ( );
		if (defined($d->{'scsiid'}) && defined($d->{'controller'})) {
			push(@ctrl, &text('index_dscsi', $d->{'scsiid'},
						         $d->{'controller'}));
			}
		if ($d->{'raid'}) {
			push(@ctrl, &text('index_draid', $d->{'raid'}));
			}
		if ($ed && &supports_hdparm($d)) {
			# Display link to IDE params form
			push(@links, "<a href='edit_hdparm.cgi?".
			     "disk=$d->{'index'}'>$text{'index_dhdparm'}</a>");
			}
		if (&supports_smart($d)) {
			# Display link to smart module
			push(@links, "<a href='../smart-status/index.cgi?".
			    "drive=$d->{'device'}:'>$text{'index_dsmart'}</a>");
			}
		if ($ed) {
			push(@links, "<a href='blink.cgi?".
                       		"disk=$d->{'index'}'>$text{'index_blink'}</a>");
                	}
		print &ui_columns_row([
			$ed ? &ui_link("edit_disk.cgi?device=$d->{'device'}",$d->{'desc'})
			    : $d->{'desc'},
			$d->{'size'} ? &nice_size($d->{'size'}) : "",
			$d->{'model'},
			scalar(@{$d->{'parts'}}),
			$hasctrl ? ( join(" ", @ctrl) ) : ( ),
			&ui_links_row(\@links),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_none2'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});

