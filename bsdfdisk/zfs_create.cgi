#!/usr/local/bin/perl
# Create a ZFS filesystem (dataset) within the pool owning this device

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'newfs_zfs_err'});

# Validate input parameters to prevent command injection
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error("Invalid device name");
$in{'device'} !~ /\.\./ or &error("Invalid device name");
$in{'slice'} =~ /^\d+$/ or &error("Invalid slice number");
$in{'part'} =~ /^[a-z]$/ or &error("Invalid partition letter") if $in{'part'};

&has_command('zfs') or &error($text{'newfs_zfs_nozfs'});

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my ($object, $part);
if ($in{'part'} ne '') {
	($part) = grep { $_->{'letter'} eq $in{'part'} } @{$slice->{'parts'}};
	$part || &error($text{'part_egone'});
	$object = $part;
}
else {
	$object = $slice;
}

# Determine ZFS pool for this device
my $zdev = get_zfs_device_info($object);
$zdev || &error($text{'newfs_zfs_notinpool'});
my $parent = $zdev->{'pool'};

# Validate dataset name
my $name = $in{'zfs'}; $name =~ s/^\s+|\s+$//g if defined $name;
$name && $name =~ /^[a-zA-Z0-9_\-.:]+$/ or &error($text{'newfs_zfs_badname'});
my $dataset = $parent . "/" . $name;

# Allowed property values
my %allowed = (
	'recordsize' => { map { $_ => 1 } qw(512 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M) },
	'compression' => { map { $_ => 1 } qw(on off lz4 gzip) },
	'atime' => { map { $_ => 1 } qw(on off) },
	'sync' => { map { $_ => 1 } qw(standard always disabled) },
	'exec' => { map { $_ => 1 } qw(on off) },
	'canmount' => { map { $_ => 1 } qw(on off noauto) },
	'acltype' => { map { $_ => 1 } qw(nfsv4 posixacl) },
	'aclinherit' => { map { $_ => 1 } qw(discard noallow restricted passthrough passthrough-x) },
	'aclmode' => { map { $_ => 1 } qw(discard groupmask passthrough) },
	'xattr' => { map { $_ => 1 } qw(on off sa) },
);

my @props = qw(recordsize compression atime sync exec canmount acltype aclinherit aclmode xattr);
my @opts;
foreach my $p (@props) {
	next if (!defined $in{$p} || $in{$p} eq '' || $in{$p} eq 'default');
	$allowed{$p} && $allowed{$p}->{$in{$p}} or &error(&text('newfs_zfs_badopt', $p));
	push(@opts, "-o $p=" . &quote_path($in{$p}));
}
if (defined $in{'mountpoint'} && $in{'mountpoint'} ne '') {
	push(@opts, "-o mountpoint=" . &quote_path($in{'mountpoint'}));
}

&ui_print_unbuffered_header($object->{'desc'}, $text{'newfs_zfs_title'}, "");

print &text('newfs_zfs_creating', "<tt>$dataset</tt>"),"<br>\n";
print "<pre>\n";
my $cmd = "zfs create " . join(" ", @opts) . " " . &quote_path($dataset);
&additional_log('exec', undef, $cmd);
my $fh;
&open_execute_command($fh, $cmd, 2);
if ($fh) {
	while(<$fh>) { print &html_escape($_); }
	close($fh);
}
print "</pre>";
if ($?) {
	print $text{'newfs_zfs_failed'},"<p>\n";
} else {
	# Optional ACL inherit flags
	if ($in{'add_inherit'}) {
		my $cmd2 = acl_inherit_flags_cmd($dataset);
		if ($cmd2) { system($cmd2); }
	}
	print $text{'newfs_zfs_done'},"<p>\n";
	&webmin_log("zfs-create", "dataset", $dataset, { parent => $parent });
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
