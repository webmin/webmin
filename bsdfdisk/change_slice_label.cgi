#!/usr/local/bin/perl
# Change the label of a slice (GPT label or glabel)

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();

# Validate input parameters to prevent command injection
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error("Invalid device name");
$in{'device'} !~ /\.\./ or &error("Invalid device name");
$in{'slice'} =~ /^\d+$/ or &error("Invalid slice number");

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});

my $base_device = $disk->{'device'}; $base_device =~ s{^/dev/}{};
my $disk_structure = get_disk_structure($base_device);
my $current_label = get_device_label_name(disk => $disk, slice => $slice, disk_structure => $disk_structure);
my $suggested_label = $slice->{'device'}; $suggested_label =~ s{^/dev/}{};

&ui_print_header($slice->{'desc'}, $text{'slice_label_title'}, "");

print &ui_form_start("save_slice_label.cgi", "post");
print &ui_hidden("device", $in{'device'});
print &ui_hidden("slice", $in{'slice'});
print &ui_table_start($text{'slice_label_header'}, undef, 2);
print &ui_table_row($text{'part_device'}, "<tt>".html_escape($slice->{'device'})."</tt>");
print &ui_table_row($text{'slice_label_current'}, $current_label ? "<tt>".html_escape($current_label)."</tt>" : "-");
print &ui_table_row($text{'slice_label_new'},
    &ui_textbox("label", $suggested_label, 20));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
    $text{'slice_return'});
