#!/usr/local/bin/perl
# Change the type of a slice

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'save_err'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

if ($in{'delete'}) {
	# Delete the slice
	my $err = &delete_slice($disk, $slice);
	&error($err) if ($err);
	&webmin_log("delete", "slice", $slice->{'device'}, $slice);
	}
else {
	# Validate inputs
	$in{'type'} =~ /^\S+$/ || &error($text{'save_etype'});
	$in{'label'} =~ /^[a-zA-Z0-9._-]+$/ || &error($text{'save_elabel'});

	# Update the slice
	my $oldslice = { %$slice };
	$slice->{'type'} = $in{'type'};
	$slice->{'label'} = $in{'label'};
	my $err = &modify_slice($disk, $oldslice, $slice);
	&error($err) if ($err);
	&webmin_log("modify", "slice", $slice->{'device'}, $slice);
	}

&redirect("edit_disk.cgi?device=$in{'device'}");
