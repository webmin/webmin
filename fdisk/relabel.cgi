#!/usr/local/bin/perl
# Re-write the partition table

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'device'}) || &error($text{'disk_ecannot'});

# Get the disk
@disks = &list_disks_partitions();
($d) = grep { $_->{'device'} eq $in{'device'} } @disks;
$d || &error($text{'disk_egone'});

# Wipe the partition
&set_partition_table($d->{'device'}, $in{'table'});
&redirect("edit_disk.cgi?device=$in{'device'}");
