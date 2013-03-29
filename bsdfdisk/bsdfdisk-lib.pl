# Functions for FreeBSD disk management
#
# XXX include in makedist.pl
# XXX exclude from Solaris, RPM, Deb
# XXX editing parititions and slices
# XXX active slice
# XXX change slice type
# XXX slice start and end overlap?

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount");
&foreign_require("fdisk");

sub check_fdisk
{
foreach my $cmd ("fdisk", "disklabel") {
	if (!&has_command($cmd)) {
		return &text('index_ecmd', "<tt>$cmd</tt>");
		}
	}
return undef;
}

# list_disks_partitions()
# Returns a list of all disks, slices and partitions
sub list_disks_partitions
{
my @rv;

# Iterate over disk devices
foreach my $dev (glob("/dev/ada[0-9]"),
		 glob("/dev/ad[0-9]"),
		 glob("/dev/da[0-9]")) {
	next if (!-r $dev || -l $dev);
	my $disk = { 'device' => $dev,
		     'prefix' => $dev,
		     'type' => $dev =~ /^\/dev\/da/ ? 'scsi' : 'ide',
		     'slices' => [ ] };
	if ($dev =~ /^\/dev\/(.*)/) {
		$disk->{'short'} = $1;
		}
	if ($dev =~ /^\/dev\/([a-z]+)(\d+)/) {
		$disk->{'desc'} = &text('select_device',
					uc($disk->{'type'}), "$2");
		}
	$disk->{'index'} = scalar(@rv);
	push(@rv, $disk);

	# Get size and slices
	my $out = &backquote_command("fdisk $dev");
	my @lines = split(/\r?\n/, $out);
	my $slice;
	for(my $i=0; $i<@lines; $i++) {
		if ($lines[$i] =~ /cylinders=(\d+)\s+heads=(\d+)\s+sectors\/track=(\d+)\s+\((\d+)/) {
			# Disk information
			$disk->{'cylinders'} = $1;
			$disk->{'heads'} = $2;
			$disk->{'sectors'} = $3;
			$disk->{'blksper'} = $4;
			$disk->{'blocks'} = $disk->{'cylinders'} *
					    $disk->{'blksper'};
			$disk->{'blocksize'} = 512;	# Guessed?
			$disk->{'size'} = $disk->{'blocks'} *
					  $disk->{'blocksize'};
			}
		elsif ($lines[$i+1] !~ /<UNUSED>/ &&
		       $lines[$i] =~ /data\s+for\s+partition\s+(\d+)/) {
			# Start of a slice
			$slice = { 'number' => $1,
				   'device' => $dev."s".$1,
				   'index' => scalar(@{$disk->{'slices'}}) };
			if ($slice->{'device'} =~ /^\/dev\/([a-z]+)(\d+)s(\d+)/){
				$slice->{'desc'} = &text('select_slice',
					uc($disk->{'type'}), "$2", "$3");
				}
			push(@{$disk->{'slices'}}, $slice);
			}
		elsif ($lines[$i] =~ /sysid\s+(\d+)\s+\(0x([0-9a-f]+)/ && $slice) {
			# Slice type
			$slice->{'type'} = $2;
			}
		elsif ($lines[$i] =~ /start\s+(\d+),\s+size\s+(\d+)\s+\((.*)\)/ && $slice) {
			# Slice start and size
			$slice->{'startblock'} = $1;
			$slice->{'blocks'} = $2;
			$slice->{'size'} = &string_to_size("$3");
			}
		elsif ($lines[$i] =~ /beg:\s+cyl\s+(\d+)/ && $slice) {
			# Slice start
			$slice->{'start'} = $1;
			}
		elsif ($lines[$i] =~ /end:\s+cyl\s+(\d+)/ && $slice) {
			# Slice end
			$slice->{'end'} = $1;
			}
		}

	# Get disk model from dmesg
	open(DMESG, "/var/run/dmesg.boot");
	while(<DMESG>) {
		if (/^(\S+):\s+<(.*)>/ && $1 eq $disk->{'short'}) {
			$disk->{'model'} = $2;
			}
		elsif (/^(\S+):\s+(\d+)(\S+)\s+\((\d+)\s+(\d+)\s+byte\s+sectors/ &&
		       $1 eq $disk->{'short'}) {
			$disk->{'sectorsize'} = $5;
			$disk->{'size'} = &string_to_size("$2 $3");
			}
		}
	close(DMESG);

	# Get partitions within slices
	foreach my $slice (@{$disk->{'slices'}}) {
		$slice->{'parts'} = [ ];
		my $out = &backquote_command("disklabel ".$slice->{'device'});
		my @lines = split(/\r?\n/, $out);
		foreach my $l (@lines) {
			if ($l =~ /^\s*([a-z]):\s+(\d+)\s+(\d+)\s+(\S+)/ &&
			    $4 ne 'unused') {
				my $part = { 'letter' => $1,
					     'blocks' => $2,
					     'startblock' => $3,
					     'type' => $4,
					     'device' =>$slice->{'device'}.$1 };
				$part->{'size'} = $part->{'blocks'} *
						  $disk->{'blocksize'};
				push(@{$slice->{'parts'}}, $part);
				}
			}
		}
	}

return @rv;
}

# string_to_size(str)
# Convert a string like 100 Meg to a number in bytes
sub string_to_size
{
my ($str) = @_;
my ($n, $pfx) = split(/\s+/, $str);
if ($pfx =~ /^b/i) {
	return $n;
	}
if ($pfx =~ /^k/i) {
	return $n * 1024;
	}
if ($pfx =~ /^m/i) {
	return $n * 1024 * 1024;
	}
if ($pfx =~ /^g/i) {
	return $n * 1024 * 1024 * 1024;
	}
if ($pfx =~ /^t/i) {
	return $n * 1024 * 1024 * 1024 * 1024;
	}
return undef;
}

# partition_select(name, value, mode, &found, disk-regexp)
# Returns HTML for a selector for a slice. The mode parameter means :
# 1 = disks
# 2 = disks and partitions
# 3 = disk partitions
sub partition_select
{
my ($name, $value, $mode, $found, $diskre) = @_;
my @opts;
my @dlist = &list_disks_partitions();
foreach my $d (@dlist) {
	my $dev = $d->{'device'};
        next if ($diskre && $dev !~ /$diskre/);
	if ($mode == 1 || $mode == 2) {
		push(@opts, [ $dev, &partition_description($dev) ]);
		}
	foreach my $s (@{$d->{'slices'}}) {
		foreach my $p (@{$s->{'parts'}}) {
			push(@opts, [ $p->{'device'},
				    &partition_description($p->{'device'}) ]);
			}
		}
	}
if ($found && &indexof($value, map { $_->[0] } @opts) >= 0) {
	$$found = 1;
	}
return &ui_select($name, $value, \@opts);
}

# partition_description(device)
# Returns a human-readable description for a device name
sub partition_description
{
my ($dev) = @_;
if ($dev =~ /^\/dev\/([a-z]+)(\d+)$/) {
	# A whole disk of some type
	return &text('select_device',
		$1 eq 'da' ? 'SCSI' : 'IDE', "$2");
	}
elsif ($dev =~ /^\/dev\/([a-z]+)(\d+)s(\d+)$/) {
	# A slice within a disk
	return &text('select_slice',
		$1 eq 'da' ? 'SCSI' : 'IDE', "$2", "$3");
	}
elsif ($dev =~ /^\/dev\/([a-z]+)(\d+)s(\d+)([a-z])$/) {
	# A partition within a slice
	return &text('select_part',
		$1 eq 'da' ? 'SCSI' : 'IDE', "$2", "$3", uc($4));
	}
else {
	# No idea
	return $dev;
	}
}

# execute_fdisk_commands(&disk, &commands)
# Run a series of commands on a disk via the fdisk config file
sub execute_fdisk_commands
{
my ($disk, $cmds) = @_;
my $temp = &transname();
my $fh = "TEMP";
&open_tempfile($fh, ">$temp");
foreach my $c (@$cmds) {
	&print_tempfile($fh, $c."\n");
	}
&close_tempfile($fh);
my $out = &backquote_logged("fdisk -f $temp $disk->{'device'} </dev/null 2>&1");
my $ex = $?;
&unlink_file($temp);
return $ex ? $out : undef;
}

# delete_slice(&disk, &slice)
# Delete one slice from a disk
sub delete_slice
{
my ($disk, $slice) = @_;
return &execute_fdisk_commands($disk,
	[ "p $slice->{'number'} 0 0 0" ]);
}

# create_slice(&disk, &slice)
# Add a slice to a disk
sub create_slice
{
my ($disk, $slice) = @_;
my $type = hex($slice->{'type'});
my $start = int(($slice->{'startblock'} * $disk->{'blocksize'}) / 1024);
my $end = int((($slice->{'startblock'} + $slice->{'blocks'}) *
	      $disk->{'blocksize'}) / 1024);
my $err = &execute_fdisk_commands($disk,
	[ "p $slice->{'number'} $type ${start}K ${end}K" ]);
if (!$err) {
	$slice->{'device'} = $disk->{'device'}."s".$slice->{'number'};
	}
return $err;
}

# initialize_slice(&disk, &slice)
# After a slice is created, put a default label on it
sub initialize_slice
{
my ($disk, $slice) = @_;
my $err = &backquote_logged("bsdlabel -w $slice->{'device'}");
return $? ? $err : undef;
}

sub list_partition_types
{
return ( '4.2BSD', 'swap', 'unused', 'vinum' );
}

# create_partition(&disk, &slice, &part)
# Create a new partition on some slice
sub create_partition
{
my ($disk, $slice, $part) = @_;
my $out = &backquote_command("bsdlabel $slice->{'device'}");
if ($? && $out =~ /no\s+valid\s+label/) {
	# No label at all yet .. initialize
	my $err = &initialize_slice($disk, $slice);
	return "Failed to create initial disk label : $err" if ($err);
	}

# Edit or add a line in the existing label
my $wantline = "  ".$part->{'letter'}.": ".$part->{'blocks'}." ".
	       $part->{'startblock'}." ".$part->{'type'};
my @lines = split(/\r?\n/, $out);
my $found = 0;
for(my $i=0; $i<@lines; $i++) {
	if ($lines[$i] =~ /^\s+(\S+):/ && $1 eq $part->{'letter'}) {
		$lines[$i] = $wantline;
		$found++;
		last;
		}
	}
if (!$found) {
	push(@lines, $wantline);
	}

# Write to a temp file
my $fh = "TEMP";
my $temp = &transname();
&open_tempfile($fh, ">$temp");
foreach my $l (@lines) {
	&print_tempfile($fh, $l."\n");
	}
&close_tempfile($fh);

# Apply the new label
$out = &backquote_logged("bsdlabel -R $slice->{'device'} $temp");
my $ex = $?;
&unlink_file($temp);
if (!$ex) {
	$part->{'device'} = $slice->{'device'}.$part->{'letter'};
	}
return $ex ? $out : undef;
}

# delete_partition(&disk, &slice, &part)
# Delete a partition on some slice
sub delete_partition
{
my ($disk, $slice, $part) = @_;

# Fix up the line for the part being deleted
my $out = &backquote_command("bsdlabel $slice->{'device'}");
my @lines = split(/\r?\n/, $out);
my $found = 0;
for(my $i=0; $i<@lines; $i++) {
	if ($lines[$i] =~ /^\s+(\S+):/ && $1 eq $part->{'letter'}) {
		splice(@lines, $i, 1);
		}
	}

# Write to a temp file
my $fh = "TEMP";
my $temp = &transname();
&open_tempfile($fh, ">$temp");
foreach my $l (@lines) {
	&print_tempfile($fh, $l."\n");
	}
&close_tempfile($fh);

# Apply the new label
$out = &backquote_logged("bsdlabel -R $slice->{'device'} $temp");
my $ex = $?;
&unlink_file($temp);
return $ex ? $out : undef;
}

1;
