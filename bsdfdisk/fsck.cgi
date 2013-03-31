#!/usr/local/bin/perl
# Check the filesystem on a partition

use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'fsck_err'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my ($part) = grep { $_->{'letter'} eq $in{'part'} } @{$slice->{'parts'}};
$part || &error($text{'part_egone'});

&ui_print_unbuffered_header($part->{'desc'}, $text{'fsck_title'}, "");

# Do the creation
print &text('fsck_checking', "<tt>$part->{'device'}</tt>"),"<br>\n";
print "<pre>\n";
my $cmd = &get_check_filesystem_command($disk, $slice, $part);
&additional_log('exec', undef, $cmd);
my $fh = "CMD";
&open_execute_command($fh, $cmd, 2);
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
print "</pre>";
if ($?) {
	print $text{'fsck_failed'},"<p>\n";
	}
else {
	print $text{'fsck_done'},"<p>\n";
	}
&webmin_log("fsck", "part", $part->{'device'}, $part);

&ui_print_footer(
    "edit_part.cgi?device=$in{'device'}&slice=$in{'slice'}&part=$in{'part'}",
    $text{'part_return'});
