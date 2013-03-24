#!/usr/local/bin/perl
# Show partitions on one disk

use strict;
use warnings;
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
push(@info, &text('disk_device', "<tt>$disk->{'device'}</tt>"));
print &ui_links_row(\@info),"<p>\n";

# Show partitions table
my @links = ( "<a href='edit_part.cgi?device=".&urlize($disk->{'device'}).
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
		$text{'disk_parts'},
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

		# Add row for the slice
		my $url = "edit_slice.cgi?device=".&urlize($disk->{'device'}).
			  "&part=".$p->{'number'};
		print &ui_columns_row([
			"<a href='$url'>$p->{'number'}</a>",
			"<a href='$url'>".&fdisk::tag_name($p->{'type'})."</a>",
			$ext,
			&nice_size($p->{'size'}),
			$p->{'startblock'},
			$p->{'startblock'} + $p->{'blocks'},
			scalar(@{$p->{'parts'}}),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'disk_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_return'});
