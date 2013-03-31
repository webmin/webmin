#!/usr/local/bin/perl
# Actually create a new slice

use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'nslice_err'});

# Get the disk
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});

# Validate inputs, starting with slice number
my $slice = { };
$in{'number'} =~ /^\d+$/ || &error($text{'nslice_enumber'});
my ($clash) = grep { $_->{'number'} == $in{'number'} } @{$disk->{'slices'}};
$clash && &error(&text('nslice_eclash', $in{'number'}));
$slice->{'number'} = $in{'number'};

# Start and end blocks
$in{'start'} =~ /^\d+$/ || &error($text{'nslice_estart'});
$in{'end'} =~ /^\d+$/ || &error($text{'nslice_eend'});
$in{'start'} < $in{'end'} || &error($text{'nslice_erange'});
$slice->{'startblock'} = $in{'start'};
$slice->{'blocks'} = $in{'end'} - $in{'start'};

# Slice type
$slice->{'type'} = $in{'type'};

# Do the creation
&ui_print_header($disk->{'desc'}, $text{'nslice_title'}, "");

print &text('nslice_creating', $in{'number'}, $disk->{'desc'}),"<p>\n";
my $err = &create_slice($disk, $slice);
if ($err) {
	print &text('nslice_failed', $err),"<p>\n";
	}
else {
	print &text('nslice_done'),"<p>\n";
	}

if (!$err && $in{'makepart'}) {
	# Also create a partition
	print &text('nslice_parting', $in{'number'}, $disk->{'desc'}),"<p>\n";
	my $err = &initialize_slice($disk, $slice);
	if ($err) {
		print &text('nslice_pfailed', $err),"<p>\n";
		}
	else {
		print &text('nslice_pdone'),"<p>\n";
		}
	}

if (!$err) {
	&webmin_log("create", "slice", $slice->{'device'}, $slice);
	}

&ui_print_footer("edit_disk.cgi?device=$in{'device'}",
		 $text{'disk_return'});

