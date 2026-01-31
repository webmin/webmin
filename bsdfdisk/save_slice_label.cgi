#!/usr/local/bin/perl
# Save slice label (GPT label or glabel)

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'slice_label_err'});

# Validate input parameters to prevent command injection
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error("Invalid device name");
$in{'device'} !~ /\.\./ or &error("Invalid device name");
$in{'slice'} =~ /^\d+$/ or &error("Invalid slice number");

my $label = defined $in{'label'} ? $in{'label'} : '';
$label =~ s/^\s+|\s+$//g;
$label ne '' || &error($text{'slice_label_empty'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

# Ensure we can set labels on this scheme
my $base_device = $disk->{'device'}; $base_device =~ s{^/dev/}{};
my $ds = get_disk_structure($base_device);
if (!$ds || !$ds->{'scheme'} || $ds->{'scheme'} !~ /GPT/i) {
    if (!has_command('glabel')) {
        &error($text{'slice_label_noglabel'});
    }
}

my $err = set_partition_label(
    disk  => $disk,
    slice => $slice,
    label => $label,
);
&error($err) if ($err);

&webmin_log("label", "slice", $slice->{'device'}, { 'label' => $label });
&redirect("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}");
