#!/usr/local/bin/perl
# Show details of a partition, with buttons to create a filesystem

use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my ($part) = grep { $_->{'letter'} eq $in{'part'} } @{$slice->{'parts'}};
$part || &error($text{'part_egone'});

&ui_print_header($part->{'desc'}, $text{'part_title'}, "");

# Show current details
print &ui_table_start($text{'part_header'}, undef, 2);

print &ui_table_row($text{'part_device'},
	"<tt>$part->{'device'}</tt>");

print &ui_table_row($text{'part_size'},
	&nice_size($part->{'size'}));

print &ui_table_row($text{'part_type'},
	$part->{'type'});

print &ui_table_row($text{'part_start'},
	$part->{'startblock'});

print &ui_table_row($text{'part_end'},
	$part->{'startblock'} + $part->{'blocks'});

my @st = &fdisk::device_status($part->{'device'});
my $use = &fdisk::device_status_link(@st);
print &ui_table_row($text{'part_use'},
	@st ? $use : $text{'part_nouse'});

print &ui_table_end();

# Show newfs and mount buttons
if (!@st || !$st[2]) {
	my $hiddens = &ui_hidden("device", $in{'device'}).
		      &ui_hidden("slice", $in{'slice'}).
		      &ui_hidden("part", $in{'part'});
	print &ui_hr();

	print &ui_buttons_start();

	print &ui_buttons_row(
		"newfs_form.cgi", $text{'part_newfs'}, $text{'part_newfsdesc'},
		$hiddens);

	print &ui_buttons_row(
		"fsck.cgi", $text{'part_fsck'}, $text{'part_fsckdesc'},
		$hiddens);

	print &ui_buttons_row(
		"delete_part.cgi", $text{'part_delete'},
		$text{'part_deletedesc'}, $hiddens);

	print &ui_buttons_end();
	}

&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
		 $text{'slice_return'});
