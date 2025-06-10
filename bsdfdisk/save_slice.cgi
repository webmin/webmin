#!/usr/local/bin/perl
# Change the type of a slice

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'slice_err'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

# Apply changes
my $oldslice = { %$slice };
$slice->{'type'} = $in{'type'};
if (!$slice->{'active'}) {
	$slice->{'active'} = $in{'active'};
	}
my $err = &modify_slice($disk, $oldslice, $slice);
&error($err) if ($err);

&webmin_log("modify", "slice", $slice->{'device'}, $slice);
&redirect("edit_disk.cgi?device=$in{'device'}");
