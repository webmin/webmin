#!/usr/local/bin/perl
# Actually create a new partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'npart_err'});

# Get the disk
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

# Validate inputs, starting with slice number
my $part = { };
$in{'letter'} =~ /^[a-d]$/i || &error($text{'npart_eletter'});
$in{'letter'} = lc($in{'letter'});
my ($clash) = grep { $_->{'letter'} eq $in{'letter'} } @{$slice->{'parts'}};
$clash && &error(&text('npart_eclash', $in{'letter'}));
$part->{'letter'} = $in{'letter'};

# Start and end blocks
$in{'start'} =~ /^\d+$/ || &error($text{'nslice_estart'});
$in{'end'} =~ /^\d+$/ || &error($text{'nslice_eend'});
$in{'start'} < $in{'end'} || &error($text{'npart_erange'});
$part->{'startblock'} = $in{'start'};
$part->{'blocks'} = $in{'end'} - $in{'start'};

# Slice type
$part->{'type'} = $in{'type'};

# Do the creation
&ui_print_header($slice->{'desc'}, $text{'npart_title'}, "");

print &text('npart_creating', $in{'letter'}, $slice->{'desc'}),"<p>\n";
my $err = &save_partition($disk, $slice, $part);
if ($err) {
	print &text('npart_failed', $err),"<p>\n";
	}
else {
	print &text('npart_done'),"<p>\n";
	&webmin_log("create", "part", $part->{'device'}, $part);
	}

&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
		 $text{'slice_return'});
