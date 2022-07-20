#!/usr/local/bin/perl
# Show details of a slice, and partitions on it

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
my $extwidth = 300;

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

&ui_print_header($slice->{'desc'}, $text{'slice_title'}, "");

# Show slice details
my @st = &fdisk::device_status($slice->{'device'});
my $use = &fdisk::device_status_link(@st);
my $canedit = !@st || !$st[2];
my $hiddens = &ui_hidden("device", $in{'device'})."\n".
	      &ui_hidden("slice", $in{'slice'})."\n";
print &ui_form_start("save_slice.cgi");
print $hiddens;
print &ui_table_start($text{'slice_header'}, undef, 2);

print &ui_table_row($text{'part_device'},
	"<tt>$slice->{'device'}</tt>");

print &ui_table_row($text{'slice_ssize'},
	&nice_size($slice->{'size'}));

print &ui_table_row($text{'slice_sstart'},
	$slice->{'startblock'});

print &ui_table_row($text{'slice_send'},
	$slice->{'startblock'} + $slice->{'blocks'} - 1);

print &ui_table_row($text{'slice_stype'},
	&ui_select("type", $slice->{'type'},
		   [ sort { $a->[1] cmp $b->[1] }
			  map { [ $_, &fdisk::tag_name($_) ] }
			      &fdisk::list_tags() ]));

print &ui_table_row($text{'slice_sactive'},
	$slice->{'active'} ? $text{'yes'} :
		&ui_yesno_radio("active", $slice->{'active'}));

print &ui_table_row($text{'slice_suse'},
	!@st ? $text{'part_nouse'} :
	$st[2] ? &text('part_inuse', $use) :
		 &text('part_foruse', $use));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

print &ui_hr();

# Show partitions table
my @links = ( "<a href='part_form.cgi?device=".&urlize($disk->{'device'}).
	      "&slice=$in{'slice'}'>".$text{'slice_add'}."</a>" );
if (@{$slice->{'parts'}}) {
	print &ui_links_row(\@links);
	print &ui_columns_start([
		$text{'slice_letter'},
		$text{'slice_type'},
		$text{'slice_extent'},
		$text{'slice_size'},
		$text{'slice_start'},
		$text{'slice_end'},
		$text{'slice_use'},
		]);
	foreach my $p (@{$slice->{'parts'}}) {
		# Create images for the extent
                my $ext = "";
                $ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
                        $extwidth*($p->{'startblock'} - 1) /
                        $slice->{'blocks'};
                $ext .= sprintf "<img src=images/%s.gif height=10 width=%d>",
                        $p->{'extended'} ? "ext" : "use",
                        $extwidth*($p->{'blocks'}) /
                        $slice->{'blocks'};
                $ext .= sprintf "<img src=images/gap.gif height=10 width=%d>",
                  $extwidth*($slice->{'blocks'} - $p->{'startblock'} -
			     $p->{'blocks'}) / $slice->{'blocks'};

		# Work out use
		my @st = &fdisk::device_status($p->{'device'});
		my $use = &fdisk::device_status_link(@st);

		# Add row for the partition
		my $url = "edit_part.cgi?device=".&urlize($disk->{'device'}).
			  "&slice=".$slice->{'number'}."&part=".$p->{'letter'};
		print &ui_columns_row([
			"<a href='$url'>".uc($p->{'letter'})."</a>",
			"<a href='$url'>$p->{'type'}</a>",
			$ext,
			&nice_size($p->{'size'}),
			$p->{'startblock'},
			$p->{'startblock'} + $p->{'blocks'} - 1,
			$use,
			]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	}
else {
	# No partitions yet
	if (@st) {
		# And directly in use, so none can be created
		print "<b>$text{'slice_none2'}</b><p>\n";
		}
	else {
		# Show link to add first partition
		print "<b>$text{'slice_none'}</b><p>\n";
		print &ui_links_row(\@links);
		}
	}

if ($canedit) {
	print &ui_hr();
	print &ui_buttons_start();

	if (!@{$slice->{'parts'}}) {
		&show_filesystem_buttons($hiddens, \@st, $slice);
		}

	# Button to delete slice
	print &ui_buttons_row(
		'delete_slice.cgi',
		$text{'slice_delete'},
		$text{'slice_deletedesc'},
		&ui_hidden("device", $in{'device'})."\n".
		&ui_hidden("slice", $in{'slice'}));

	print &ui_buttons_end();
	}


&ui_print_footer("edit_disk.cgi?device=$in{'device'}",
		 $text{'disk_return'});
