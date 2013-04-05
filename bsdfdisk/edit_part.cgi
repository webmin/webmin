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
my @st = &fdisk::device_status($part->{'device'});
my $use = &fdisk::device_status_link(@st);
my $canedit = !@st || !$st[2];
my $hiddens = &ui_hidden("device", $in{'device'})."\n".
	      &ui_hidden("slice", $in{'slice'})."\n".
	      &ui_hidden("part", $in{'part'})."\n";
if ($canedit) {
	print &ui_form_start("save_part.cgi", "post");
	print $hiddens;
	}
print &ui_table_start($text{'part_header'}, undef, 2);

print &ui_table_row($text{'part_device'},
	"<tt>$part->{'device'}</tt>");

print &ui_table_row($text{'part_size'},
	&nice_size($part->{'size'}));

print &ui_table_row($text{'part_start'},
	$part->{'startblock'});

print &ui_table_row($text{'part_end'},
	$part->{'startblock'} + $part->{'blocks'} - 1);

if ($canedit) {
	print &ui_table_row($text{'part_type'},
		&ui_select("type", $part->{'type'},
			   [ &list_partition_types() ], 1, 0, 1));
	}
else {
	print &ui_table_row($text{'part_type'},
		$part->{'type'});
	}

print &ui_table_row($text{'part_use'},
	!@st ? $text{'part_nouse'} :
	$st[2] ? &text('part_inuse', $use) :
		 &text('part_foruse', $use));

print &ui_table_end();
if ($canedit) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

# Show newfs and mount buttons
if ($canedit) {
	print &ui_hr();

	print &ui_buttons_start();

	&show_filesystem_buttons($hiddens, \@st, $part);

	print &ui_buttons_row(
		"delete_part.cgi", $text{'part_delete'},
		$text{'part_deletedesc'}, $hiddens);

	print &ui_buttons_end();
	}
else {
	print "<b>$text{'part_cannotedit'}</b><p>\n";
	}

&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
		 $text{'slice_return'});
