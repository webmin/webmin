#!/usr/local/bin/perl
# Show a form for creating a new partition

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

&ui_print_header($slice->{'desc'}, $text{'npart_title'}, "");

print &ui_form_start("create_part.cgi", "post");
print &ui_hidden("device", $in{'device'});
print &ui_hidden("slice", $in{'slice'});
print &ui_table_start($text{'npart_header'}, undef, 2);

# Partition number (first free)
my %used = map { $_->{'letter'}, $_ } @{$slice->{'parts'}};
my $l = 'a';
while($used{$l}) {
	$l++;
	}
print &ui_table_row($text{'npart_letter'},
	&ui_textbox("letter", $l, 4));

# Slice size in blocks
print &ui_table_row($text{'npart_diskblocks'},
	$slice->{'blocks'});

# Start and end blocks (defaults to last part)
my ($start, $end) = (0, $slice->{'blocks'});
foreach my $p (sort { $a->{'startblock'} cmp $b->{'startblock'} }
		    @{$slice->{'parts'}}) {
	$start = $p->{'startblock'} + $p->{'blocks'} + 1;
	}
print &ui_table_row($text{'nslice_start'},
	&ui_textbox("start", $start, 10));
print &ui_table_row($text{'nslice_end'},
	&ui_textbox("end", $end, 10));

# Partition type
print &ui_table_row($text{'npart_type'},
	&ui_select("type", '4.2BSD',
		   [ &list_partition_types() ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
		 $text{'slice_return'});
