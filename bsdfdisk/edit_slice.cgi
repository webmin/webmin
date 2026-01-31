#!/usr/local/bin/perl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
ReadParse();
my $extwidth = 300;
# Get the disk and slice
my @disks = list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks or error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}} or error($text{'slice_egone'});
ui_print_header($slice->{'desc'}, $text{'slice_title'}, "");
# Show slice details
my $zfs_info = get_all_zfs_info();
my ($zfs_pools, $zfs_devices) = build_zfs_devices_cache();
# Cache slice device status
my @slice_status = fdisk::device_status($slice->{'device'});
my $slice_use = $zfs_info->{$slice->{'device'}} ? $zfs_info->{$slice->{'device'}} : fdisk::device_status_link(@slice_status);
my $canedit = (! @slice_status || !$slice_status[2]);
# Prepare hidden fields
my $hiddens = ui_hidden("device", $in{'device'}) . "\n" . ui_hidden("slice", $in{'slice'}) . "\n";
# Derive disk scheme for classifier
my $base_device = $disk->{'device'}; $base_device =~ s{^/dev/}{};
my $disk_structure = get_disk_structure($base_device);
# Device label (GPT label or glabel)
my $slice_label = get_device_label_name(disk => $disk, slice => $slice, disk_structure => $disk_structure);
# Check if this is a boot slice
my $is_boot = is_boot_partition($slice);
print ui_alert_box($text{'slice_bootdesc'}, 'info') if $is_boot;
print ui_form_start("save_slice.cgi");
print $hiddens;
print ui_table_start($text{'slice_header'}, undef, 2);
print ui_table_row($text{'part_device'}, "<tt>$slice->{'device'}</tt>");
print ui_table_row($text{'slice_label'}, $slice_label ? "<tt>$slice_label</tt>" : "-");
my $slice_bytes = bytes_from_blocks($slice->{'device'}, $slice->{'blocks'});
print ui_table_row($text{'slice_ssize'}, $slice_bytes ? safe_nice_size($slice_bytes) : '-');
print ui_table_row($text{'slice_sstart'}, $slice->{'startblock'});
print ui_table_row($text{'slice_send'}, $slice->{'startblock'} + $slice->{'blocks'} - 1);
# Slice type selector (GPT vs legacy)
if (is_using_gpart()) {
    my $scheme = ($disk_structure && $disk_structure->{'scheme'}) ? $disk_structure->{'scheme'} : 'GPT';
    my @opts = list_partition_types($scheme);
    # Default sensibly per scheme
    my $default_type = ($scheme =~ /GPT/i) ? 'freebsd-zfs' : 'freebsd';
    print ui_table_row($text{'slice_stype'}, ui_select("type", $slice->{'type'} || $default_type, \@opts));
}
else {
    # Pre-cache tag options for the slice type select (legacy fdisk)
    my @tags = fdisk::list_tags();
    my @tag_options = map { [ $_, fdisk::tag_name($_) ] } @tags;
    @tag_options = sort { $a->[1] cmp $b->[1] } @tag_options;
    print ui_table_row($text{'slice_stype'}, ui_select("type", $slice->{'type'}, \@tag_options));
}
# Active slice - only applicable for legacy MBR. For GPT/UEFI and for EFI/freebsd-boot types, the active flag is irrelevant.
my $is_gpt = is_using_gpart() && ($disk_structure && $disk_structure->{'scheme'} && $disk_structure->{'scheme'} =~ /GPT/i);
if (!$is_gpt && ($slice->{'type'} !~ /^(?:efi|freebsd-boot)$/i)) {
    my $active_default = $slice->{'active'} ? 1 : 0;
    print ui_table_row($text{'slice_sactive'}, ui_yesno_radio("active", $active_default));
} else {
    # Do not offer the control; display 'No' since active is not used here
    print ui_table_row($text{'slice_sactive'}, $text{'no'});
}
print ui_table_row($text{'slice_suse'},
    (!$slice_use || $slice_use eq $text{'part_nouse'})
        ? $text{'part_nouse'}
        : ($slice_status[2] ? text('part_inuse', $slice_use) : text('part_foruse', $slice_use)));
# Add a row for the slice role
print ui_table_row($text{'slice_role'}, get_partition_role($slice));
print ui_table_end();
print ui_form_end([ [ undef, $text{'save'} ] ]);
print ui_hr();
# Show partitions table (only for MBR slices that support BSD disklabel)
my $can_have_parts = 0;
if (!is_using_gpart()) {
    # Legacy MBR with BSD disklabel
    $can_have_parts = 1;
} elsif ($disk_structure && $disk_structure->{'scheme'} && $disk_structure->{'scheme'} !~ /GPT/i) {
    # MBR-style slice
    $can_have_parts = 1;
}
my @links = $can_have_parts ? ( "<a href='part_form.cgi?device=" . urlize($disk->{'device'}) . "&slice=$in{'slice'}'>" . $text{'slice_add'} . "</a>" ) : ();
if (@{$slice->{'parts'}}) {
    print ui_links_row(\@links) if @links;
    print ui_columns_start([
        $text{'slice_letter'},
        $text{'slice_type'},
        $text{'slice_extent'},
        $text{'slice_size'},
        $text{'slice_start'},
        $text{'slice_end'},
        $text{'disk_stripesize'},
        $text{'slice_use'},
        $text{'slice_role'},
    ]);
    
    # Pre-calculate scaling factor for the partition extent images
    my $scale = $extwidth / $slice->{'blocks'};
    
    foreach my $p (@{$slice->{'parts'}}) {
        # Create images representing the partition extent
        my $gap_before = sprintf("<img src=images/gap.gif height=10 width=%d>", int($scale * ($p->{'startblock'} - 1)));
        my $img_type   = $p->{'extended'} ? "ext" : "use";
        my $partition_img = sprintf("<img src=images/%s.gif height=10 width=%d>", $img_type, int($scale * $p->{'blocks'}));
        my $gap_after  = sprintf("<img src=images/gap.gif height=10 width=%d>", int($scale * ($slice->{'blocks'} - $p->{'startblock'} - $p->{'blocks'})));
        my $ext = $gap_before . $partition_img . $gap_after;
        
        # Cache partition device status information
        my @part_status = fdisk::device_status($p->{'device'});
        my $part_use = $zfs_info->{$p->{'device'}} || fdisk::device_status_link(@part_status);
        # Prefer GEOM details for stripesize
        my $ginfo = get_detailed_disk_info($p->{'device'});
        my $stripesize = ($ginfo && $ginfo->{'stripesize'}) ? $ginfo->{'stripesize'} : '-';
        
        # Classify format/use/role via library helper
        (my $pn = $p->{'device'}) =~ s{^/dev/}{};
        my ($fmt, $use_txt, $role_txt) = classify_partition_row(
            base_device     => $base_device,
            scheme          => ($disk_structure->{'scheme'} || ''),
            part_name       => $pn,
            entry_part_type => $p->{'type'},
            zfs_devices     => $zfs_devices,
        );
        $use_txt ||= $part_use;
        $role_txt ||= get_partition_role($p);
        
        # Build edit URL
        my $url = "edit_part.cgi?device=" . urlize($disk->{'device'}) . "&slice=" . $slice->{'number'} . "&part=" . $p->{'letter'};
        my $psz_b = bytes_from_blocks($p->{'device'}, $p->{'blocks'});
        print ui_columns_row([
            "<a href='$url'>" . uc($p->{'letter'}) . "</a>",
            "<a href='$url'>" . ($fmt || get_format_type($p)) . "</a>",
            $ext,
            ($psz_b ? safe_nice_size($psz_b) : '-'),
            $p->{'startblock'},
            $p->{'startblock'} + $p->{'blocks'} - 1,
            $stripesize,
            $use_txt,
            $role_txt,
        ]);
    }
    print ui_columns_end();
    print ui_links_row(\@links) if @links;
} else {
    # GPT partitions do not have sub-partitions
    if (!$can_have_parts) {
        # No message needed for GPT; partitions are top-level
    }
    # If slice is in use by a filesystem OR it is a boot slice, do not allow creating partitions
    elsif (@slice_status || $zfs_info->{$slice->{'device'}} || $is_boot) {
        print "<b>$text{'slice_none2'}</b><p>\n";
    } else {
        print "<b>$text{'slice_none'}</b><p>\n";
        print ui_links_row(\@links) if @links;
    }
}
if ($canedit && !$is_boot) {  # Do not allow editing boot slices
    print ui_hr();
    print ui_buttons_start();
    if (!@{$slice->{'parts'}}) {
        my $mount_return = "edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}";
        show_filesystem_buttons($hiddens, \@slice_status, $slice, $mount_return);
    }
    print ui_buttons_row(
        'change_slice_label.cgi',
        $text{'slice_chglabel'},
        $text{'slice_chglabeldesc'},
        ui_hidden("device", $in{'device'}) . "\n" . ui_hidden("slice", $in{'slice'})
    );
    print ui_buttons_row(
        'delete_slice.cgi',
        $text{'slice_delete'},
        $text{'slice_deletedesc'},
        ui_hidden("device", $in{'device'}) . "\n" . ui_hidden("slice", $in{'slice'})
    );
    print ui_buttons_end();
}
# SMART button (physical device)
if (&has_command("smartctl")) {
    print ui_hr();
    print ui_buttons_start();
    print ui_buttons_row("smart.cgi", $text{'disk_smart'}, $text{'disk_smartdesc'},
        ui_hidden("device", $disk->{'device'}));
    print ui_buttons_end();
}

ui_print_footer("edit_disk.cgi?device=$in{'device'}", $text{'disk_return'});
