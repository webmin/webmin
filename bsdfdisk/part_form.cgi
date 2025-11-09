#!/usr/local/bin/perl
# Show a form for creating a new partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
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

# Partition number (first free, skipping 'c' which is reserved for the whole slice)
my %used = map { $_->{'letter'}, $_ } @{$slice->{'parts'}};
$used{'c'} = 1;  # Reserve 'c' for the whole slice (BSD convention)
my $l = 'a';
while($used{$l}) {
	$l++;
	}
print &ui_table_row($text{'npart_letter'},
	&ui_textbox("letter", $l, 4) . " <i>(" . $text{'npart_creserved'} . ")</i>");

# Slice size in blocks
print &ui_table_row($text{'npart_diskblocks'},
	$slice->{'blocks'});

# Start and end blocks for BSD partitions are SLICE-RELATIVE (not disk-absolute)
# Start at 0 (or after last partition), end at slice size - 1
my ($start, $end) = (0, $slice->{'blocks'} - 1);
foreach my $p (sort { $a->{'startblock'} <=> $b->{'startblock'} }
      @{$slice->{'parts'}}) {
   # Partitions are already stored as slice-relative
   $start = $p->{'startblock'} + $p->{'blocks'};
}
if (defined $in{'start'} && $in{'start'} =~ /^\d+$/) { $start = $in{'start'}; }
if (defined $in{'end'} && $in{'end'} =~ /^\d+$/) { $end = $in{'end'}; }
print &ui_table_row($text{'nslice_start'} . " " . $text{'npart_slicerel'},
   &ui_textbox("start", $start, 10));
print &ui_table_row($text{'nslice_end'} . " " . $text{'npart_slicerel'},
    &ui_textbox("end", $end, 10));
 
# Partition type
# For BSD-on-MBR inner label partitions, offer FreeBSD partition types
my $scheme = 'BSD';
my $default_ptype = 'freebsd-ufs';
print &ui_table_row($text{'npart_type'},
   &ui_select("type", $default_ptype,
               [ list_partition_types($scheme) ]));
 
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

# Existing partitions summary
if (@{$slice->{'parts'}||[]}) {
    my $zfs = get_all_zfs_info();
    print &ui_hr();
    print &ui_columns_start([
        $text{'slice_letter'}, $text{'slice_type'}, $text{'slice_start'}, $text{'slice_end'}, $text{'slice_size'}, $text{'slice_use'}, $text{'slice_role'}
    ], $text{'epart_existing'});
    foreach my $p (sort { $a->{'startblock'} <=> $b->{'startblock'} } @{$slice->{'parts'}}) {
        my $ptype = get_type_description($p->{'type'}) || $p->{'type'};
        my @stp = fdisk::device_status($p->{'device'});
        my $usep = $zfs->{$p->{'device'}} || fdisk::device_status_link(@stp) || $text{'part_nouse'};
        my $rolep = get_partition_role($p);
        my $pb = bytes_from_blocks($p->{'device'}, $p->{'blocks'});
        print &ui_columns_row([
            uc($p->{'letter'}), $ptype, $p->{'startblock'}, $p->{'startblock'} + $p->{'blocks'} - 1, ($pb ? safe_nice_size($pb) : '-'), $usep, $rolep
        ]);
    }
    print &ui_columns_end();
}
 
&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
         $text{'slice_return'});