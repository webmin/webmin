#!/usr/local/bin/perl
# Show details of a disk, and slices on it

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
my $extwidth = 300;

# Get the disk
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});

&ui_print_header($disk->{'desc'}, $text{'disk_title'}, "");

# Show disk details
my @info = ( );
push(@info, &text('disk_dsize', &nice_size($disk->{'size'})));
if ($disk->{'model'}) {
        push(@info, &text('disk_model', $disk->{'model'}));
        }
push(@info, &text('disk_cylinders', $disk->{'cylinders'}));
push(@info, &text('disk_blocks', $disk->{'blocks'}));
push(@info, &text('disk_device', "<tt>$disk->{'device'}</tt>"));
print &ui_links_row(\@info),"<p>\n";

# Show partitions table
my @links = ( "<a href='slice_form.cgi?device=".&urlize($disk->{'device'}).
	      "&new=1'>".$text{'disk_add'}."</a>" );
if (@{$disk->{'slices'}}) {
	print &ui_links_row(\@links);
	print &ui_columns_start([
		$text{'disk_no'},
		$text{'disk_type'},
		$text{'disk_extent'},
		$text{'disk_size'},
		$text{'disk_start'},
		$text{'disk_end'},
		$text{'disk_use'},
		]);
	foreach my $p (@{$disk->{'slices'}}) {
		# Create images for the extent
                my $ext = "";
                $ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
                        $extwidth*($p->{'startblock'} - 1) /
                        $disk->{'blocks'};
                $ext .= sprintf "<img src=images/%s.gif height=10 width=%d>",
                        $p->{'extended'} ? "ext" : "use",
                        $extwidth*($p->{'blocks'}) /
                        $disk->{'blocks'};
                $ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
                  $extwidth*($disk->{'blocks'} - $p->{'startblock'} -
			     $p->{'blocks'}) / $disk->{'blocks'};

		# Work out use
		my @st = &fdisk::device_status($p->{'device'});
		my $use = &fdisk::device_status_link(@st);
		my $n = scalar(@{$p->{'parts'}});

		# Add row for the slice
		my $url = "edit_slice.cgi?device=".&urlize($disk->{'device'}).
			  "&slice=".$p->{'number'};
		my $nlink = "<a href='$url'>$p->{'number'}</a>";
		$nlink = "<b>$nlink</b>" if ($p->{'active'});
		print &ui_columns_row([
			$nlink,
			"<a href='$url'>".&fdisk::tag_name($p->{'type'})."</a>",
			$ext,
			&nice_size($p->{'size'}),
			$p->{'startblock'},
			$p->{'startblock'} + $p->{'blocks'} - 1,
			$use ? $use :
			  $n ? &text('disk_scount', $n) : "",
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'disk_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

print &ui_hr();
print &ui_buttons_start();

if (&foreign_installed("smart-status")) {
	print &ui_buttons_row(
		"../smart-status/index.cgi",
		$text{'disk_smart'},
		$text{'disk_smartdesc'},
		&ui_hidden("drive", $disk->{'device'}.":"));
	}

print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});
