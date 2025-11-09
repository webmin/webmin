#!/usr/local/bin/perl
use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, %config, $module_name);

# Check prerequisites first
my $err = check_fdisk();
if ($err) {
    ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0);
    print "<b>$text{'index_problem'}</b><br>\n$err\n";
    ui_print_footer("/", $text{'index_return'});
    exit;
}

# Print header with help link
ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
                help_search_link("fdisk", "man"));

# List and sort disks by device name
my @disks = list_disks_partitions();
@disks = sort { ($a->{'device'}//'') cmp ($b->{'device'}//'') } @disks;

if (@disks) {
    print ui_columns_start([
        $text{'index_dname'},
        $text{'index_dsize'},
        $text{'index_dmodel'},
        $text{'index_dparts'}
    ]);

    foreach my $d (@disks) {
        my $device      = $d->{'device'} // '';
        my $disk_name   = $device; $disk_name =~ s{^/dev/}{};
        # Prefer mediasize from gpart list (bytes); fallback to diskinfo size
        my $base = $device; $base =~ s{^/dev/}{};
        my $ds = get_disk_structure($base);
        my $bytes = $ds && $ds->{'mediasize'} ? $ds->{'mediasize'} : $d->{'size'};
        my $size_display = defined $bytes ? safe_nice_size($bytes) : '-';
        my $model       = $d->{'model'} // '-';
        my $url_device  = urlize($device);
        my $slices_cnt  = scalar(@{ $d->{'slices'} || [] });

        print ui_columns_row([
            "<a href='edit_disk.cgi?device=$url_device'>$disk_name</a>",
            $size_display,
            $model,  # Now correctly populated from bsdfdisk-lib.pl
            $slices_cnt,
        ]);
    }
    print ui_columns_end();
}
else {
    print "<b>$text{'index_none'}</b><p>\n";
}

ui_print_footer("/", $text{'index_return'});