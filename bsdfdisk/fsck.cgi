#!/usr/local/bin/perl
# Check the filesystem on a partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
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

# Safety checks: do not run fsck on boot partitions or in-use devices
if (is_boot_partition($object)) {
    &error($in{'part'} ne '' ? $text{'part_eboot'} : $text{'slice_eboot'});
}
my @st_obj = &fdisk::device_status($object->{'device'});
my $use_obj = &fdisk::device_status_link(@st_obj);
if (@st_obj && $st_obj[2]) {
    &error(&text('part_esave', $use_obj));
}

&ui_print_unbuffered_header($object->{'desc'}, $text{'fsck_title'}, "");

# If device is ZFS, do not run fsck; show zpool status instead
my $zmap = get_all_zfs_info();
if ($zmap->{$object->{'device'}}) {
    my $pool = $zmap->{$object->{'device'}}; $pool =~ s/^.*?\b([A-Za-z0-9_\-]+)\b.*$/$1/;
    print &text('fsck_checking', "<tt>$object->{'device'}</tt>"),"<br>\n";
    print "<pre>\n";
    my $cmd = "zpool status 2>&1";
    &additional_log('exec', undef, $cmd);
    print &html_escape(&backquote_command($cmd));
    print "</pre>";
    print $text{'fsck_done'},"<p>\n";
} else {
    # Do the creation
    print &text('fsck_checking', "<tt>$object->{'device'}</tt>"),"<br>\n";
    print "<pre>\n";
    my $cmd = &get_check_filesystem_command($disk, $slice, $part);
    &additional_log('exec', undef, $cmd);
    my $fh;
    &open_execute_command($fh, $cmd, 2);
    if ($fh) {
        while (my $line = <$fh>) {
            $line =~ s/[^\x09\x0A\x0D\x20-\x7E]//g;
            print &html_escape($line);
        }
        close($fh);
    }
    print "</pre>";
    if ($?) {
        print $text{'fsck_failed'},"<p>\n";
    }
    else {
        print $text{'fsck_done'},"<p>\n";
    }
}
&webmin_log("fsck", $in{'part'} ne '' ? "part" : "object",
        $object->{'device'}, $object);

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