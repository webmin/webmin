#!/usr/local/bin/perl
# Create a ZFS volume (zvol) within the pool owning this device

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();
&error_setup($text{'newfs_zvol_err'});

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

# Validate zvol name and size
my $name = $in{'zvol'}; $name =~ s/^\s+|\s+$//g if defined $name;
$name && $name =~ /^[a-zA-Z0-9_\-.:]+$/ or &error($text{'newfs_zvol_badname'});
my $size = $in{'size'}; $size =~ s/^\s+|\s+$//g if defined $size;
$size && $size =~ /^\d+(\.\d+)?[KMGTP]?$/i or &error($text{'newfs_zvol_badsize'});
my $dataset = $parent . "/" . $name;

# Allowed property values
my %allowed = (
	'volblocksize' => { map { $_ => 1 } qw(512 1K 2K 4K 8K 16K 32K 64K 128K) },
	'compression'  => { map { $_ => 1 } qw(on off lz4 gzip) },
	'sync'         => { map { $_ => 1 } qw(standard always disabled) },
	'logbias'      => { map { $_ => 1 } qw(latency throughput) },
	'primarycache' => { map { $_ => 1 } qw(all metadata none) },
	'secondarycache' => { map { $_ => 1 } qw(all metadata none) },
);

my @props = qw(volblocksize compression sync logbias primarycache secondarycache);
my @opts;
foreach my $p (@props) {
	next if (!defined $in{$p} || $in{$p} eq '' || $in{$p} eq 'default');
	$allowed{$p} && $allowed{$p}->{$in{$p}} or &error(&text('newfs_zvol_badopt', $p));
	push(@opts, "-o $p=" . &quote_path($in{$p}));
}

my $sparse = $in{'sparse'};
my $refres = $in{'refreservation'};
if (defined $refres) {
	$refres =~ s/^\s+|\s+$//g;
	if ($refres ne '' && lc($refres) ne 'none') {
		$refres =~ /^\d+(\.\d+)?[KMGTP]?$/i or &error($text{'newfs_zvol_badrefres'});
		push(@opts, "-o refreservation=" . &quote_path($refres));
	}
}

&ui_print_unbuffered_header($object->{'desc'}, $text{'newfs_zvol_title'}, "");

print &text('newfs_zvol_creating', "<tt>".&html_escape($dataset)."</tt>"),"<br>\n";
print "<pre>\n";
my $cmd = "zfs create " . ($sparse ? "-s " : "") . "-V " . &quote_path($size) . " " .
          join(" ", @opts) . " " . &quote_path($dataset);
&additional_log('exec', undef, $cmd);
my $fh;
&open_execute_command($fh, $cmd, 2);
if ($fh) {
	while(<$fh>) { print &html_escape($_); }
	close($fh);
}
print "</pre>";
if ($?) {
	print $text{'newfs_zvol_failed'},"<p>\n";
} else {
	print $text{'newfs_zvol_done'},"<p>\n";
	&webmin_log("zfs-create", "zvol", $dataset, { parent => $parent, volsize => $size });
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
