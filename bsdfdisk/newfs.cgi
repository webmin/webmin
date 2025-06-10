#!/usr/local/bin/perl
# Create a filesystem on a partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'newfs_err'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my ($object, $part);
if ($in{'part'} ne '') {
	($part) = grep { $_->{'letter'} eq $in{'part'} }
		       @{$slice->{'parts'}};
	$part || &error($text{'part_egone'});
	$object = $part;
	}
else {
	$object = $slice;
	}

# Validate inputs
my $newfs = { };
$in{'free_def'} || $in{'free'} =~ /^\d+$/ && $in{'free'} <= 100 ||
	&error($text{'newfs_efree'});
$newfs->{'free'} = $in{'free_def'} ? undef : $in{'free'};
$newfs->{'trim'} = $in{'trim'};
$in{'label_def'} || $in{'label'} =~ /^\S+$/ ||
	&error($text{'newfs_elabel'});
$newfs->{'label'} = $in{'label_def'} ? undef : $in{'label'};

&ui_print_unbuffered_header($object->{'desc'}, $text{'newfs_title'}, "");

# Do the creation
print &text('newfs_creating', "<tt>$object->{'device'}</tt>"),"<br>\n";
print "<pre>\n";
my $cmd = &get_create_filesystem_command($disk, $slice, $part, $newfs);
&additional_log('exec', undef, $cmd);
my $fh = "CMD";
&open_execute_command($fh, $cmd, 2);
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
print "</pre>";
if ($?) {
	print $text{'newfs_failed'},"<p>\n";
	}
else {
	print $text{'newfs_done'},"<p>\n";
	&webmin_log("newfs", $in{'part'} ne '' ? "part" : "object",
		    $object->{'device'}, $object);
	}

if ($in{'part'} ne '') {
	&ui_print_footer("edit_part.cgi?device=$in{'device'}&".
			   "slice=$in{'slice'}&part=$in{'part'}",
			 $text{'part_return'});
	}
else {
	&ui_print_footer("edit_slice.cgi?device=$in{'device'}&".
			   "slice=$in{'slice'}",
			 $text{'slice_return'});
	}
