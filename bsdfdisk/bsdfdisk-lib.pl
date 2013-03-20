# Functions for FreeBSD disk management
#
# XXX call from mount module
# XXX include in makedist.pl
# XXX exclude from Solaris, RPM, Deb
# XXX editing parititions and slices
# XXX top-level is really called slice?
# XXX disk cylinders don't match slice size

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount");
&foreign_require("fdisk");

sub check_fdisk
{
if (!&has_command("fdisk")) {
	return &text('index_ecmd', "<tt>fdisk</tt>");
	}
return undef;
}

# list_disks_partitions()
# Returns a list of all disks, partitions and slices
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
		     'parts' => [ ] };
	if ($dev =~ /^\/dev\/(.*)/) {
		$disk->{'short'} = $1;
		}
	if ($dev =~ /^\/dev\/([a-z]+)(\d+)/) {
		$disk->{'desc'} = &text('select_device',
					uc($disk->{'type'}), "$2");
		}
	$disk->{'index'} = scalar(@rv);
	push(@rv, $disk);

	# Get size and partitions
	my $out = &backquote_command("fdisk $dev");
	my @lines = split(/\r?\n/, $out);
	my $part;
	for(my $i=0; $i<@lines; $i++) {
		if ($lines[$i] =~ /cylinders=(\d+)\s+heads=(\d+)\s+sectors\/track=(\d+)\s+\((\d+)/) {
			# Disk information
			$disk->{'cylinders'} = $1;
			$disk->{'heads'} = $2;
			$disk->{'sectors'} = $3;
			$disk->{'blksper'} = $4;
			$disk->{'size'} = $disk->{'cylinders'} *
					  $disk->{'blksper'} * 512;
			}
		elsif ($lines[$i+1] !~ /<UNUSED>/ &&
		       $lines[$i] =~ /data\s+for\s+partition\s+(\d+)/) {
			# Start of a partition
			$part = { 'number' => $1,
				  'device' => $dev."s".$1,
				  'index' => scalar(@{$disk->{'parts'}}) };
			if ($part->{'device'} =~ /^\/dev\/([a-z]+)(\d+)s(\d+)/){
				$part->{'desc'} = &text('select_part',
					uc($disk->{'type'}), "$2", "$3");
				}
			push(@{$disk->{'parts'}}, $part);
			}
		elsif ($lines[$i] =~ /sysid\s+(\d+)\s+\(0x([0-9a-f]+)/ && $part) {
			# Partition type
			$part->{'type'} = $2;
			}
		elsif ($lines[$i] =~ /start\s+(\d+),\s+size\s+(\d+)\s+\((.*)\)/ && $part) {
			# Partition start and size
			$part->{'blocks'} = $2;
			$part->{'size'} = &string_to_size("$3");
			}
		elsif ($lines[$i] =~ /beg:\s+cyl\s+(\d+)/ && $part) {
			# Partition start
			$part->{'start'} = $1;
			}
		elsif ($lines[$i] =~ /end:\s+cyl\s+(\d+)/ && $part) {
			# Partition end
			$part->{'end'} = $1;
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

	# Get slices within partitions
	# XXX
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

1;
