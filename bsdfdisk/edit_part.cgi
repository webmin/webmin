#!/usr/local/bin/perl
use strict;
use warnings;
use List::Util qw(first);
# Load required libraries
require "./bsdfdisk-lib.pl";
our ( %in, %text, $module_name );
ReadParse();
# Cache input parameters to avoid repeated hash lookups
my $device     = $in{'device'};
my $slice_num  = $in{'slice'};
my $part_letter = $in{'part'};
# Get the disk and slice using first() to stop at the first matching element
my @disks = list_disks_partitions();
my $disk = first { $_->{'device'} eq $device } @disks;
$disk or error($text{'disk_egone'});
my $slice = first { $_->{'number'} eq $slice_num } @{ $disk->{'slices'} };
$slice or error($text{'slice_egone'});
my $part = first { $_->{'letter'} eq $part_letter } @{ $slice->{'parts'} };
$part or error($text{'part_egone'});
ui_print_header($part->{'desc'}, $text{'part_title'}, "");
# Check if this is a boot partition
my $is_boot = is_boot_partition($part);
if ($is_boot) {
    print ui_alert_box($text{'part_bootdesc'}, 'info');
}
# Show current details
my $zfs_info = get_all_zfs_info();
my @st       = fdisk::device_status($part->{'device'});
# calculate $use from either ZFS info or from a status link
my $device_path = $part->{'device'};
my $use = $zfs_info->{ $device_path } || fdisk::device_status_link(@st);
my $canedit = (!@st && !$zfs_info->{ $device_path } && !$is_boot);
# Prepare hidden fields once
my $hiddens = ui_hidden("device", $device) . "\n" .
              ui_hidden("slice",  $slice_num) . "\n" . 
              ui_hidden("part",   $part_letter) . "\n";
if ($canedit) {
    print ui_form_start("save_part.cgi", "post"), $hiddens;
}
print ui_table_start($text{'part_header'}, undef, 2);
print ui_table_row($text{'part_device'}, "<tt>$part->{'device'}</tt>");
my $part_bytes = bytes_from_blocks($part->{'device'}, $part->{'blocks'});
print ui_table_row($text{'part_size'},   $part_bytes ? safe_nice_size($part_bytes) : '-');
print ui_table_row($text{'part_start'},  $part->{'startblock'});
print ui_table_row($text{'part_end'},    $part->{'startblock'} + $part->{'blocks'} - 1);
my $disk_geom = get_detailed_disk_info($disk->{'device'});
my $stripesize = ($disk_geom && $disk_geom->{'stripesize'}) ? $disk_geom->{'stripesize'} : '-';
print ui_table_row($text{'disk_stripesize'}, $stripesize);
if ($canedit) {
    # BSD disklabel partitions only support FreeBSD types
    print ui_table_row($text{'part_type'},
        ui_select("type", $part->{'type'}, [ list_partition_types('BSD') ], 1, 0, 1));
} else {
    print ui_table_row($text{'part_type'}, get_format_type($part));
}
my $use_text = ((!@st && !$zfs_info->{ $part->{'device'} })
    ? $text{'part_nouse'}
    : (($st[2] || $zfs_info->{ $part->{'device'} })
        ? text('part_inuse', $use)
        : text('part_foruse', $use)));
print ui_table_row($text{'part_use'}, $use_text);
# Add a row for the partition role
print ui_table_row($text{'part_role'}, get_partition_role($part));
print ui_table_end();
if ($canedit) {
    print ui_form_end([[ undef, $text{'save'} ]]);
}

# Existing partitions on this slice
if (@{ $slice->{'parts'} || [] }) {
    my $zfs = get_all_zfs_info();
    print ui_hr();
    print ui_columns_start([
        $text{'slice_letter'}, $text{'slice_type'}, $text{'slice_start'}, $text{'slice_end'}, $text{'slice_size'}, $text{'slice_use'}, $text{'slice_role'}
    ], $text{'epart_existing'});
    foreach my $p (sort { $a->{'startblock'} <=> $b->{'startblock'} } @{ $slice->{'parts'} }) {
        my $ptype = get_type_description($p->{'type'}) || $p->{'type'};
        my @stp = fdisk::device_status($p->{'device'});
        my $usep = $zfs->{$p->{'device'}} || fdisk::device_status_link(@stp) || $text{'part_nouse'};
        my $rolep = get_partition_role($p);
        my $pb2 = bytes_from_blocks($p->{'device'}, $p->{'blocks'});
        print ui_columns_row([
            uc($p->{'letter'}), $ptype, $p->{'startblock'}, $p->{'startblock'} + $p->{'blocks'} - 1, ($pb2 ? safe_nice_size($pb2) : '-'), $usep, $rolep
        ]);
    }
    print ui_columns_end();
}

# Show newfs and mount buttons if editing is allowed
if ($canedit) {
    print ui_hr();
    print ui_buttons_start();
    show_filesystem_buttons($hiddens, \@st, $part);
    print ui_buttons_row("delete_part.cgi", $text{'part_delete'}, $text{'part_deletedesc'}, $hiddens);
    print ui_buttons_end();
} else {
    print ($is_boot) ? "<b>$text{'part_bootcannotedit'}</b><p>\n"
                     : "<b>$text{'part_cannotedit'}</b><p>\n";
}
# SMART button (physical device)
if (&has_command("smartctl")) {
    print ui_hr();
    print ui_buttons_start();
    print ui_buttons_row("smart.cgi", $text{'disk_smart'}, $text{'disk_smartdesc'},
        ui_hidden("device", $disk->{'device'}));
    print ui_buttons_end();
}
ui_print_footer("edit_slice.cgi?device=$device&slice=$slice_num", $text{'slice_return'});