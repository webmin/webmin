#!/usr/local/bin/perl
# Change the type of a partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'part_err'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my ($part) = grep { $_->{'letter'} eq $in{'part'} } @{$slice->{'parts'}};
$part || &error($text{'part_egone'});

# Check if in use
my @st = &fdisk::device_status($part->{'device'});
my $use = &fdisk::device_status_link(@st);
if (@st && $st[2]) {
	&error(&text('part_esave', $use));
	}

# Make the change
$part->{'type'} = $in{'type'};
my $err = &save_partition($disk, $slice, $part);
&error($err) if ($err);

&webmin_log("modify", "part", $part->{'device'}, $part);
&redirect("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}");
