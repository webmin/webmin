# fdisk-lib.pl
# Functions for disk management under linux

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount", "mount-lib.pl");
if (&foreign_check("raid")) {
	&foreign_require("raid");
	$raid_module++;
	}
if (&foreign_check("lvm")) {
	&foreign_require("lvm");
	$lvm_module++;
	}
if (&foreign_check("iscsi-server")) {
	&foreign_require("iscsi-server");
	$iscsi_server_module++;
	}
if (&foreign_check("iscsi-target")) {
	&foreign_require("iscsi-target");
	$iscsi_target_module++;
	}
&foreign_require("proc", "proc-lib.pl");
%access = &get_module_acl();
$has_e2label = &has_command("e2label");
$has_xfs_db = &has_command("xfs_db");
$has_volid = &has_command("vol_id");
$has_reiserfstune = &has_command("reiserfstune");
$uuid_directory = "/dev/disk/by-uuid";
if ($config{'mode'} eq 'parted') {
	$has_parted = 1;
	}
elsif ($config{'mode'} eq 'fdisk') {
	$has_parted = 0;
	}
else {
	$has_parted = !$config{'noparted'} && &has_command("parted") &&
		      &get_parted_version() >= 1.8;
	}
$| = 1;

# list_disks_partitions([include-cds])
# Returns a structure containing the details of all disks and partitions
sub list_disks_partitions
{
if (scalar(@list_disks_partitions_cache)) {
	return @list_disks_partitions_cache;
	}

local (@pscsi, @dscsi, $dscsi_mode);
if (-r "/proc/scsi/sg/devices" && -r "/proc/scsi/sg/device_strs") {
	# Get device info from various /proc/scsi files
	open(DEVICES, "/proc/scsi/sg/devices");
	while(<DEVICES>) {
		s/\r|\n//g;
		local @l = split(/\t+/, $_);
		push(@dscsi, { 'host' => $l[0],
			       'bus' => $l[1],
			       'target' => $l[2],
			       'lun' => $l[3],
			       'type' => $l[4] });
		}
	close(DEVICES);
	local $i = 0;
	open(DEVNAMES, "/proc/scsi/sg/device_strs");
	while(<DEVNAMES>) {
		s/\r|\n//g;
		local @l = split(/\t+/, $_);
		$dscsi[$i]->{'make'} = $l[0];
		$dscsi[$i]->{'model'} = $l[1];
		$i++;
		}
	close(DEVNAMES);
	$dscsi_mode = 1;
	@dscsi = grep { $_->{'type'} == 0 } @dscsi;
	}
else {
	# Check /proc/scsi/scsi for SCSI disk models
	open(SCSI, "/proc/scsi/scsi");
	local @lines = <SCSI>;
	close(SCSI);
	if ($lines[0] =~ /^Attached\s+domains/i) {
		# New domains format
		local $dscsi;
		foreach (@lines) {
			s/\s/ /g;
			if (/Device:\s+(.*)(sd[a-z]+)\s+usage/) {
				$dscsi = { 'dev' => $2 };
				push(@dscsi, $dscsi);
				}
			elsif (/Device:/) {
				$dscsi = undef;
				}
			elsif (/Vendor:\s+(\S+)\s+Model:\s+(\S+)/ && $dscsi) {
				$dscsi->{'make'} = $1;
				$dscsi->{'model'} = $2;
				}
			elsif (/Host:\s+scsi(\d+)\s+Channel:\s+(\d+)\s+Id:\s+(\d+)\s+Lun:\s+(\d+)/ && $dscsi) {
				$dscsi->{'host'} = $1;
				$dscsi->{'bus'} = $2;
				$dscsi->{'target'} = $3;
				$dscsi->{'lun'} = $4;
				}
			}
		$dscsi_mode = 1;
		}
	else {
		# Standard format
		foreach (@lines) {
			s/\s/ /g;
			if (/^Host:/) {
				push(@pscsi, $_);
				}
			elsif (/^\s+\S/ && @pscsi) {
				$pscsi[$#pscsi] .= $_;
				}
			}
		@pscsi = grep { /Type:\s+Direct-Access/i } @pscsi;
		$dscsi_mode = 0;
		}
	}

local (@disks, @devs, $d);
if (open(PARTS, "/proc/partitions")) {
	# The list of all disks can come from the kernel
	local $sc = 0;
	while(<PARTS>) {
		if (/\d+\s+\d+\s+\d+\s+sd([a-z]+)\s/ ||
		    /\d+\s+\d+\s+\d+\s+(scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc)\s+/) {
			# New or old style SCSI device
			local $d = $1;
			local ($host, $bus, $target, $lun) = ($2, $3, $4, $5);
			if (!$dscsi_mode && $pscsi[$sc] =~ /USB-FDU/) {
				# USB floppy with scsi emulation!
				splice(@pscsi, $sc, 1);
				next;
				}
			if ($host ne '') {
				local $scsidev = "/dev/$d";
				if (!-r $scsidev) {
					push(@devs, "/dev/".
						  &number_to_device("sd", $sc));
					}
				else {
					push(@devs, $scsidev);
					}
				}
			else {
				push(@devs, "/dev/sd$d");
				}
			$sc++;
			}
		elsif (/\d+\s+\d+\s+\d+\s+hd([a-z]+)\s/) {
			# IDE disk (but skip CDs)
			local $n = $1;
			if (open(MEDIA, "/proc/ide/hd$n/media")) {
				local $media = <MEDIA>;
				close(MEDIA);
				if ($media =~ /^disk/ && !$_[0]) {
					push(@devs, "/dev/hd$n");
					}
				}
			}
		elsif (/\d+\s+\d+\s+\d+\s+(ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc)\s+/) {
			# New-style IDE disk
			local $idedev = "/dev/$1";
			local ($host, $bus, $target, $lun) = ($2, $3, $4, $5);
			if (!-r $idedev) {
				push(@devs, "/dev/".
				    &hbt_to_device($host, $bus, $target));
				}
			else {
				push(@devs, "/dev/$1");
				}
			}
		elsif (/\d+\s+\d+\s+\d+\s+(rd\/c(\d+)d\d+)\s/) {
			# Mylex raid device
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(ida\/c(\d+)d\d+)\s/) {
			# Compaq raid device
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(cciss\/c(\d+)d\d+)\s/) {
			# Compaq Smart Array RAID
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(ataraid\/disc(\d+)\/disc)\s+/) {
			# Promise raid controller
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(vd[a-z]+)\s/) {
			# Virtio disk from KVM
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(xvd[a-z]+)\s/) {
			# PV disk from Xen
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(mmcblk\d+)\s/) {
			# SD card / MMC, seen on Raspberry Pi
			push(@devs, "/dev/$1");
			}
		elsif (/\d+\s+\d+\s+\d+\s+(nvme\d+n\d+)\s/) {
			# NVME SSD
			push(@devs, "/dev/$1");
			}
		}
	close(PARTS);

	# Sort IDE first
	@devs = sort { ($b =~ /\/hd[a-z]+$/ ? 1 : 0) <=>
		       ($a =~ /\/hd[a-z]+$/ ? 1 : 0) } @devs;
	}
return ( ) if (!@devs);		# No disks, ie on Xen

# Skip cd-rom drive, identified from symlink. Don't do this if we can identify
# cds by their media type though
if (!-d "/proc/ide") {
	local @cdstat = stat("/dev/cdrom");
	if (@cdstat && !$_[0]) {
		@devs = grep { (stat($_))[1] != $cdstat[1] } @devs;
		}
	}

# Get Linux disk ID mapping
local %id_map;
local $id_dir = "/dev/disk/by-id";
opendir(IDS, $id_dir);
foreach my $id (readdir(IDS)) {
	local $id_link = readlink("$id_dir/$id");
	if ($id_link) {
		local $id_real = &simplify_path(&resolve_links("$id_dir/$id"));
		$id_map{$id_real} = $id;
		}
	}
closedir(IDS);

# Call fdisk to get partition and geometry information
local $devs = join(" ", @devs);
local ($disk, $m2);
if ($has_parted) {
	open(FDISK, join(" ; ",
		map { "parted $_ unit cyl print 2>/dev/null || ".
		      "fdisk -l $_ 2>/dev/null" } @devs)." |");
	}
else {
	open(FDISK, "fdisk -l -u=cylinders $devs 2>/dev/null || fdisk -l $devs 2>/dev/null |");
	}
while(<FDISK>) {
	if (/Disk\s+([^ :]+):\s+(\d+)\s+\S+\s+(\d+)\s+\S+\s+(\d+)/ ||
	    ($m2 = ($_ =~ /Disk\s+([^ :]+):\s+(.*)\s+bytes/)) ||
	    ($m3 = ($_ =~ /Disk\s+([^ :]+):\s+([0-9\.]+)cyl/))) {
		# New disk section
		if ($m3) {
			# Parted format
			$disk = { 'device' => $1,
				  'prefix' => $1,
				  'cylinders' => $2 };
			}
		elsif ($m2) {
			# New style fdisk
			$disk = { 'device' => $1,
				  'prefix' => $1,
				  'table' => 'msdos', };
			<FDISK> =~ /(\d+)\s+\S+\s+(\d+)\s+\S+\s+(\d+)/ || next;
			$disk->{'heads'} = $1;
			$disk->{'sectors'} = $2;
			$disk->{'cylinders'} = $3;
			}
		else {
			# Old style fdisk
			$disk = { 'device' => $1,
				  'prefix' => $1,
				  'heads' => $2,
				  'sectors' => $3,
				  'cylinders' => $4,
				  'table' => 'msdos', };
			}
		$disk->{'index'} = scalar(@disks);
		$disk->{'parts'} = [ ];

		local @st = stat($disk->{'device'});
		next if (@cdstat && $st[1] == $cdstat[1]);
		if ($disk->{'device'} =~ /\/sd([a-z]+)$/) {
			# Old-style SCSI disk
			$disk->{'desc'} = &text('select_device', 'SCSI',
						uc($1));
			local ($dscsi) = grep { $_->{'dev'} eq "sd$1" } @dscsi;
			$disk->{'scsi'} = $dscsi ? &indexof($dscsi, @dscsi)
						 : ord(uc($1))-65;
			$disk->{'type'} = 'scsi';
			}
		elsif ($disk->{'device'} =~ /\/hd([a-z]+)$/) {
			# IDE disk
			$disk->{'desc'} = &text('select_device', 'IDE', uc($1));
			$disk->{'type'} = 'ide';
			}
		elsif ($disk->{'device'} =~ /\/xvd([a-z]+)$/) {
			# Xen virtual disk
			$disk->{'desc'} = &text('select_device', 'Xen', uc($1));
			$disk->{'type'} = 'ide';
			}
		elsif ($disk->{'device'} =~ /\/mmcblk([0-9]+)$/) {
			# SD-card / MMC
			$disk->{'desc'} = &text('select_device', 'SD-Card', $1);
			$disk->{'type'} = 'ide';
			}
		elsif ($disk->{'device'} =~ /\/vd([a-z]+)$/) {
			# KVM virtual disk
			$disk->{'desc'} = &text('select_device',
						'VirtIO', uc($1));
			$disk->{'type'} = 'ide';
			}
		elsif ($disk->{'device'} =~ /\/(scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc)/) {
			# New complete SCSI disk specification
			$disk->{'host'} = $2;
			$disk->{'bus'} = $3;
			$disk->{'target'} = $4;
			$disk->{'lun'} = $5;
			$disk->{'desc'} = &text('select_scsi',
						"$2", "$3", "$4", "$5");

			# Work out the SCSI index for this disk
			local $j;
			if ($dscsi_mode) {
				for($j=0; $j<@dscsi; $j++) {
					if ($dscsi[$j]->{'host'} == $disk->{'host'} && $dscsi[$j]->{'bus'} == $disk->{'bus'} && $dscsi[$j]->{'target'} == $disk->{'target'} && $dscsi[$j]->{'lnun'} == $disk->{'lun'}) {
						$disk->{'scsi'} = $j;
						last;
						}
					}
				}
			else {
				for($j=0; $j<@pscsi; $j++) {
					if ($pscsi[$j] =~ /Host:\s+scsi(\d+).*Id:\s+(\d+)/i && $disk->{'host'} == $1 && $disk->{'target'} == $2) {
						$disk->{'scsi'} = $j;
						last;
						}
					}
				}
			$disk->{'type'} = 'scsi';
			$disk->{'prefix'} =~ s/disc$/part/g;
			}
		elsif ($disk->{'device'} =~ /\/(ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc)/) {
			# New-style IDE specification
			$disk->{'host'} = $2;
			$disk->{'bus'} = $3;
			$disk->{'target'} = $4;
			$disk->{'lun'} = $5;
			$disk->{'desc'} = &text('select_newide',
						"$2", "$3", "$4", "$5");
			$disk->{'type'} = 'ide';
			$disk->{'prefix'} =~ s/disc$/part/g;
			}
		elsif ($disk->{'device'} =~ /\/(rd\/c(\d+)d(\d+))/) {
			# Mylex raid device
			local ($mc, $md) = ($2, $3);
			$disk->{'desc'} = &text('select_mylex', $mc, $md);
			open(RD, "/proc/rd/c$mc/current_status");
			while(<RD>) {
				if (/^Configuring\s+(.*)/i) {
					$disk->{'model'} = $1;
					}
				elsif (/\s+(\S+):\s+([^, ]+)/ &&
				       $1 eq $disk->{'device'}) {
					$disk->{'raid'} = $2;
					}
				}
			close(RD);
			$disk->{'type'} = 'raid';
			$disk->{'prefix'} = $disk->{'device'}.'p';
			}
		elsif ($disk->{'device'} =~ /\/(ida\/c(\d+)d(\d+))/) {
			# Compaq RAID device
			local ($ic, $id) = ($2, $3);
			$disk->{'desc'} = &text('select_cpq', $ic, $id);
			open(IDA, -d "/proc/driver/array" ? "/proc/driver/array/ida$ic" : "/proc/driver/cpqarray/ida$ic");
			while(<IDA>) {
				if (/^(\S+):\s+(.*)/ && $1 eq "ida$ic") {
					$disk->{'model'} = $2;
					}
				}
			close(IDA);
			$disk->{'type'} = 'raid';
			$disk->{'prefix'} = $disk->{'device'}.'p';
			}
		elsif ($disk->{'device'} =~ /\/(cciss\/c(\d+)d(\d+))/) {
			# Compaq Smart Array RAID
			local ($ic, $id) = ($2, $3);
			$disk->{'desc'} = &text('select_smart', $ic, $id);
			open(CCI, "/proc/driver/cciss/cciss$ic");
			while(<CCI>) {
				if (/^\s*(\S+):\s*(.*)/ && $1 eq "cciss$ic") {
					$disk->{'model'} = $2;
					}
				}
			close(CCI);
			$disk->{'type'} = 'raid';
			$disk->{'prefix'} = $disk->{'device'}.'p';
			}
		elsif ($disk->{'device'} =~ /\/(ataraid\/disc(\d+)\/disc)/) {
			# Promise RAID controller
			local $dd = $2;
			$disk->{'desc'} = &text('select_promise', $dd);
			$disk->{'type'} = 'raid';
			$disk->{'prefix'} =~ s/disc$/part/g;
			}
		elsif ($disk->{'device'} =~ /\/nvme(\d+)n(\d+)$/) {
			# NVME SSD controller
			$disk->{'desc'} = &text('select_nvme', "$1", "$2");
			$disk->{'type'} = 'scsi';
			$disk->{'prefix'} = $disk->{'device'}.'p';
			}

		# Work out short name, like sda
		local $short;
		if (defined($disk->{'host'})) {
			$short = &hbt_to_device($disk->{'host'},
						$disk->{'bus'},
						$disk->{'target'});
			}
		else {
			$short = $disk->{'device'};
			$short =~ s/^.*\///g;
			}
		$disk->{'short'} = $short;

		$disk->{'id'} = $id_map{$disk->{'device'}} ||
				$id_map{"/dev/$short"};

		push(@disks, $disk);
		}
	elsif (/^Units\s+=\s+cylinders\s+of\s+(\d+)\s+\*\s+(\d+)/) {
		# Unit size for disk from fdisk
		$disk->{'bytes'} = $2;
		$disk->{'cylsize'} = $disk->{'heads'} * $disk->{'sectors'} *
				     $disk->{'bytes'};
		$disk->{'size'} = $disk->{'cylinders'} * $disk->{'cylsize'};
		}
	elsif (/BIOS\s+cylinder,head,sector\s+geometry:\s+(\d+),(\d+),(\d+)\.\s+Each\s+cylinder\s+is\s+(\d+)(b|kb|mb)/i) {
		# Unit size for disk from parted
		$disk->{'cylinders'} = $1;
		$disk->{'heads'} = $2;
		$disk->{'sectors'} = $3;
		$disk->{'cylsize'} = $4 * (lc($5) eq "b" ? 1 :
					   lc($5) eq "kb" ? 1024 : 1024*1024);
		$disk->{'bytes'} = $disk->{'cylsize'} / $disk->{'heads'} /
						        $disk->{'sectors'};
		$disk->{'size'} = $disk->{'cylinders'} * $disk->{'cylsize'};
		}
	elsif (/(\/dev\/\S+?(\d+))[ \t*]+\d+\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S{1,2})\s+(.*)/ || /(\/dev\/\S+?(\d+))[ \t*]+(\d+)\s+(\d+)\s+(\S+)\s+(\S{1,2})\s+(.*)/) {
		# Partition within the current disk from fdisk (msdos format)
		local $part = { 'number' => $2,
				'device' => $1,
				'type' => $6,
				'start' => $3,
				'end' => $4,
				'blocks' => int($5),
				'extended' => $6 eq '5' || $6 eq 'f' ? 1 : 0,
				'index' => scalar(@{$disk->{'parts'}}),
			 	'edittype' => 1, };
		$part->{'desc'} = &partition_description($part->{'device'});
		$part->{'size'} = ($part->{'end'} - $part->{'start'} + 1) *
				  $disk->{'cylsize'};
		push(@{$disk->{'parts'}}, $part);
		}
	elsif (/(\/dev\/\S+?(\d+))\s+(\d+)\s+(\d+)\s+(\d+)\s+([0-9\.]+[kMGTP])\s+(\S.*)/) {
		# Partition within the current disk from fdisk (gpt format)
		local $part = { 'number' => $2,
                                'device' => $1,
				'type' => $7,
				'start' => $3,
				'end' => $4,
				'blocks' => $5,
				'index' => scalar(@{$disk->{'parts'}}),
			 	'edittype' => 1, };
		$part->{'desc'} = &partition_description($part->{'device'});
		$part->{'size'} = ($part->{'end'} - $part->{'start'} + 1) *
				  $disk->{'cylsize'};
		push(@{$disk->{'parts'}}, $part);
		}
	elsif (/^\s*(\d+)\s+(\d+)cyl\s+(\d+)cyl\s+(\d+)cyl\s+(primary|logical|extended)\s*(\S*)\s*(\S*)/) {
		# Partition within the current disk from parted (msdos format)
		local $part = { 'number' => $1,
				'device' => $disk->{'device'}.$1,
				'type' => $6 || 'ext2',
				'start' => $2+1,
				'end' => $3+1,
				'blocks' => $4 * $disk->{'cylsize'},
				'extended' => $5 eq 'extended' ? 1 : 0,
				'raid' => $7 eq 'raid' ? 1 : 0,
				'index' => scalar(@{$disk->{'parts'}}),
				'edittype' => 0, };
		$part->{'type'} = 'ext2' if ($part->{'type'} =~ /^ext/);
		$part->{'type'} = 'raid' if ($part->{'type'} eq 'ext2' &&
					     $part->{'raid'});
		$part->{'desc'} = &partition_description($part->{'device'});
		$part->{'size'} = ($part->{'end'} - $part->{'start'} + 1) *
				  $disk->{'cylsize'};
		push(@{$disk->{'parts'}}, $part);
		}
	elsif (/^\s*(\d+)\s+(\d+)cyl\s+(\d+)cyl\s+(\d+)cyl\s(.*)/) {
		# Partition within the current disk from parted (gpt format)
		local $part = { 'number' => $1,
				'device' => $disk->{'device'}.$1,
				'start' => $2+1,
				'end' => $3+1,
				'blocks' => $4 * $disk->{'cylsize'},
				'extended' => 0,
				'index' => scalar(@{$disk->{'parts'}}),
				'edittype' => 0, };

		# Work out partition type, name and flags
		local $rest = $5;
		$rest =~ s/^\s+//;
		$rest =~ s/,//g;	# Remove commas in flags list
		local @rest = split(/\s+/, $rest);

		# If first word is a known partition type, assume it is the type
		if (@rest && &conv_type($rest[0])) {
			$part->{'type'} = shift(@rest);
			}

		# Remove flag words from the end
		local %flags;
		while(@rest && $rest[$#rest] =~ /boot|lba|root|swap|hidden|raid|LVM/i) {
			$flags{lc(pop(@rest))} = 1;
			}

		# Anything left in the middle should be the name
		if (@rest) {
			$part->{'name'} = $rest[0];
			}
		if ($flags{'raid'}) {
			# RAID flag is set
			$part->{'raid'} = 1;
			}
		$part->{'type'} = 'ext2' if (!$part->{'type'} ||
					     $part->{'type'} =~ /^ext/);
		$part->{'type'} = 'raid' if ($part->{'type'} =~ /^ext/ &&
					     $part->{'raid'});
		$part->{'desc'} = &partition_description($part->{'device'});
		$part->{'size'} = ($part->{'end'} - $part->{'start'} + 1) *
				  $disk->{'cylsize'};
		push(@{$disk->{'parts'}}, $part);
		}
	elsif (/Partition\s+Table:\s+(\S+)/) {
		# Parted partition table type (from parted)
		$disk->{'table'} = $1;
		}
	elsif (/Disklabel\s+type:\s+(\S+)/) {
		# Parted partition table type (from fdisk)
		$disk->{'table'} = $1;
		}
	}
close(FDISK);

# Check /proc/ide for IDE disk models
foreach $d (@disks) {
	if ($d->{'type'} eq 'ide') {
		local $short = $d->{'short'};
		$d->{'model'} = &read_file_contents("/proc/ide/$short/model");
		$d->{'model'} =~ s/\r|\n//g;
		$d->{'media'} = &read_file_contents("/proc/ide/$short/media");
		$d->{'media'} =~ s/\r|\n//g;
		if ($d->{'short'} =~ /^vd/ && !$d->{'model'}) {
			# Fake up model for KVM VirtIO disks
			$d->{'model'} = "KVM VirtIO";
			}
		}
	}

# Fill in SCSI information
foreach $d (@disks) {
	if ($d->{'type'} eq 'scsi') {
		local $s = $d->{'scsi'};
		local $sysdir = "/sys/block/$d->{'short'}/device";
		if (-d $sysdir) {
			# From kernel 2.6.30+ sys directory
			$d->{'model'} = &read_file_contents("$sysdir/vendor").
					" ".
					&read_file_contents("$sysdir/model");
			$d->{'model'} =~ s/\r|\n//g;
			$d->{'media'} = &read_file_contents("$sysdir/media");
			$d->{'media'} =~ s/\r|\n//g;
			}
		elsif ($dscsi_mode) {
			# From other scsi files
			$d->{'model'} = "$dscsi[$s]->{'make'} $dscsi[$s]->{'model'}";
			$d->{'controller'} = $dscsi[$s]->{'host'};
			$d->{'scsiid'} = $dscsi[$s]->{'target'};
			}
		else {
			# From /proc/scsi/scsi lines
			if ($pscsi[$s] =~ /Vendor:\s+(\S+).*Model:\s+(.*)\s+Rev:/i) {
				$d->{'model'} = "$1 $2";
				}
			if ($pscsi[$s] =~ /Host:\s+scsi(\d+).*Id:\s+(\d+)/i) {
				$d->{'controller'} = int($1);
				$d->{'scsiid'} = int($2);
				}
			}
		if ($d->{'model'} =~ /ATA/) {
			# Fake SCSI disk, actually IDE
			$d->{'scsi'} = 0;
			$d->{'desc'} =~ s/SCSI/SATA/g;
			foreach my $p (@{$d->{'parts'}}) {
				$p->{'desc'} =~ s/SCSI/SATA/g;
				}
			}
		}
	}

@list_disks_partitions_cache = @disks;
return @disks;
}

# partition_description(device)
# Converts a device path like /dev/hda1 into a human-readable name
sub partition_description
{
my ($device) = @_;
return $device =~ /(s|h|xv|v)d([a-z]+)(\d+)$/ ?
	 &text('select_part', $1 eq 's' ? 'SCSI' :
			      $1 eq 'xv' ? 'Xen' :
			      $1 eq 'v' ? 'VirtIO' : 'IDE', uc($2), "$3") :
       $device =~ /mmcblk(\d+)p(\d+)$/ ?
	 &text('select_part', 'SD-Card', "$1", "$2") :
       $device =~ /scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/part(\d+)/ ?
	 &text('select_spart', "$1", "$2", "$3", "$4", "$5") :
       $device =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/part(\d+)/ ?
	 &text('select_snewide', "$1", "$2", "$3", "$4", "$5") :
       $device =~ /rd\/c(\d+)d(\d+)p(\d+)$/ ? 
	 &text('select_mpart', "$1", "$2", "$3") :
       $device =~ /ida\/c(\d+)d(\d+)p(\d+)$/ ? 
	 &text('select_cpart', "$1", "$2", "$3") :
       $device =~ /cciss\/c(\d+)d(\d+)p(\d+)$/ ? 
	 &text('select_smartpart', "$1", "$2", "$3") :
       $device =~ /ataraid\/disc(\d+)\/part(\d+)$/ ?
	 &text('select_ppart', "$1", "$2") :
       $device =~ /nvme(\d+)n(\d+)p(\d+)$/ ?
	 &text('select_nvmepart', "$1", "$2", "$3") :
	 "???";
}

# hbt_to_device(host, bus, target)
# Converts an IDE device specified as a host, bus and target to an hdX device
sub hbt_to_device
{
local ($host, $bus, $target) = @_;
local $num = $host*4 + $bus*2 + $target;
return &number_to_device("hd", $num);
}

# number_to_device(suffix, number)
sub number_to_device
{
local ($suffix, $num) = @_;
if ($num < 26) {
	# Just a single letter
	return $suffix.(('a' .. 'z')[$num]);
	}
else {
	# Two-letter format
	local $first = int($num / 26);
	local $second = $num % 26;
	return $suffix.(('a' .. 'z')[$first]).(('a' .. 'z')[$second]);
	}
}

# change_type(disk, partition, type)
# Changes the type of an existing partition
sub change_type
{
my ($disk, $part, $type) = @_;
&open_fdisk($disk);
&wprint("t\n");
local $rv = &wait_for($fh, 'Partition.*:', 'Selected partition');
&wprint("$part\n") if ($rv == 0);
&wait_for($fh, 'Hex.*:');
&wprint("$type\n");
&wait_for($fh, 'Command.*:');
&wprint("w\n"); sleep(1);
&close_fdisk();
undef(@list_disks_partitions_cache);
}

# delete_partition(disk, partition)
# Delete an existing partition
sub delete_partition
{
my ($disk, $part) = @_;
if ($has_parted) {
	# Using parted
	my $cmd = "parted -s ".$disk." rm ".$part;
	my $out = &backquote_logged("$cmd </dev/null 2>&1");
	if ($?) {
		&error("$cmd failed : $out");
		}
	}
else {
	# Using fdisk
	&open_fdisk($disk);
	&wprint("d\n");
	local $rv = &wait_for($fh, 'Partition.*:', 'Selected partition');
	&wprint("$part\n") if ($rv == 0);
	&wait_for($fh, 'Command.*:');
	&wprint("w\n");
	&wait_for($fh, 'Syncing');
	sleep(3);
	&close_fdisk();
	}
undef(@list_disks_partitions_cache);
}

# create_partition(disk, partition, start, end, type)
# Create a new partition with the given extent and type
sub create_partition
{
my ($disk, $part, $start, $end, $type) = @_;
if ($has_parted) {
	# Using parted
	my $pe = $part > 4 ? "logical" : "primary";
	my $cmd;
	if ($type eq "raid") {
		$cmd = "parted -s ".$disk." unit cyl mkpart ".$pe." ".
		       "ext2 ".($start-1)." ".$end;
		$cmd .= " ; parted -s ".$disk." set $part raid on";
		}
	elsif ($type && $type ne 'ext2') {
		$cmd = "parted -s ".$disk." unit cyl mkpart ".$pe." ".
		       $type." ".($start-1)." ".$end;
		}
	else {
		$cmd = "parted -s ".$disk." unit cyl mkpart ".$pe." ".
		       ($start-1)." ".$end;
		}
	my $out = &backquote_logged("$cmd </dev/null 2>&1");
	if ($?) {
		&error("$cmd failed : $out");
		}
	}
else {
	# Using fdisk
	&open_fdisk($disk);
	&wprint("n\n");
	local $wf = &wait_for($fh, 'primary.*\r?\n', 'First.*:');
	if ($part > 4) {
		&wprint("l\n");
		}
	else {
		&wprint("p\n");
		local $wf2 = &wait_for($fh, 'Partition.*:',
					    'Selected partition');
		&wprint("$part\n") if ($wf2 == 0);
		}
	&wait_for($fh, 'First.*:') if ($wf != 1);
	&wprint("$start\n");
	$wf = &wait_for($fh, 'Last.*:', 'First.*:');
	$wf < 0 && &error("End of input waiting for first cylinder response");
	$wf == 1 && &error("First cylinder is invalid : $wait_for_input");
	&wprint("$end\n");
	$wf = &wait_for($fh, 'Command.*:', 'Last.*:');
	$wf < 0 && &error("End of input waiting for last cylinder response");
	$wf == 1 && &error("Last cylinder is invalid : $wait_for_input");

	&wprint("t\n");
	local $rv = &wait_for($fh, 'Partition.*:', 'Selected partition');
	&wprint("$part\n") if ($rv == 0);
	&wait_for($fh, 'Hex.*:');
	&wprint("$type\n");
	$wf = &wait_for($fh, 'Command.*:', 'Hex.*:');
	$wf < 0 && &error("End of input waiting for partition type response");
	$wf == 1 && &error("Partition type is invalid : $wait_for_input");
	&wprint("w\n");
	&wait_for($fh, 'Syncing'); sleep(3);
	&close_fdisk();
	}
undef(@list_disks_partitions_cache);
}

# create_extended(disk, partition, start, end)
# Create a new extended partition
sub create_extended
{
my ($disk, $part, $start, $end) = @_;
if ($has_parted) {
	# Create using parted
	my $cmd = "parted -s ".$disk." unit cyl mkpart extended ".
		  ($start-1)." ".$end;
	my $out = &backquote_logged("$cmd </dev/null 2>&1");
	if ($?) {
		&error("$cmd failed : $out");
		}
	}
else {
	# Use classic fdisk
	&open_fdisk($disk);
	&wprint("n\n");
	&wait_for($fh, 'primary.*\r?\n');
	&wprint("e\n");
	&wait_for($fh, 'Partition.*:');
	&wprint("$part\n");
	&wait_for($fh, 'First.*:');
	&wprint("$start\n");
	&wait_for($fh, 'Last.*:');
	&wprint("$end\n");
	&wait_for($fh, 'Command.*:');

	&wprint("w\n");
	&wait_for($fh, 'Syncing');
	sleep(3);
	&close_fdisk();
	}
undef(@list_disks_partitions_cache);
}

# list_tags()
# Returns a list of known partition tag numbers
sub list_tags
{
if ($has_parted) {
	# Parted types
	return sort { $a cmp $b } (keys %parted_tags);
	}
else {
	# Classic fdisk types
	return sort { hex($a) <=> hex($b) } (keys %tags);
	}
}

# tag_name(tag)
# Returns a human-readable version of a tag
sub tag_name
{
return $tags{$_[0]} || $parted_tags{$_[0]} || $hidden_tags{$_[0]};
}

sub default_tag
{
return $has_parted ? 'ext2' : '83';
}

# conv_type(tag)
# Given a partition tag, returns the filesystem type (assuming it is supported)
sub conv_type
{
my ($tag) = @_;
my @rv;
if ($has_parted) {
	# Use parted type names
	if ($tag eq "fat16") {
		@rv = ( "msdos" );
		}
	elsif ($tag eq "fat32") {
		@rv = ( "vfat" );
		}
	elsif ($tag =~ /^ext/ || $tag eq "raid") {
		@rv = ( "ext3", "ext4", "ext2", "xfs", "reiserfs", "btrfs" );
		}
	elsif ($tag eq "hfs" || $tag eq "HFS") {
		@rv = ( "hfs" );
		}
	elsif ($tag eq "linux-swap") {
		@rv = ( "swap" );
		}
	elsif ($tag eq "NTFS") {
		@rv = ( "ntfs" );
		}
	elsif ($tag eq "reiserfs") {
		@rv = "reiserfs";
		}
	elsif ($tag eq "ufs") {
		@rv = ( "ufs" );
		}
	else {
		return ( );
		}
	}
else {
	# Use fdisk type IDs
	if ($tag eq "4" || $tag eq "6" || $tag eq "1" || $tag eq "e") {
		@rv = ( "msdos" );
		}
	elsif ($tag eq "b" || $tag eq "c") {
		@rv = ( "vfat" );
		}
	elsif ($tag eq "83") {
		@rv = ( "ext3", "ext4", "ext2", "xfs", "reiserfs", "btrfs" );
		}
	elsif ($tag eq "82") {
		@rv = ( "swap" );
		}
	elsif ($tag eq "81") {
		@rv = ( "minix" );
		}
	else {
		return ( );
		}
	}
local %supp = map { $_, 1 } &mount::list_fstypes();
@rv = grep { $supp{$_} } @rv;
return wantarray ? @rv : $rv[0];
}

# fstype_name(type)
# Returns a readable name for a filesystem type
sub fstype_name
{
return $text{"fs_".$_[0]};
}

sub mkfs_options
{
if ($_[0] eq "msdos" || $_[0] eq "vfat") {
	&opt_input("msdos_ff", "", 1);
	print &ui_table_row($text{'msdos_F'},
	     &ui_select("msdos_F", undef,
			[ [ undef, $text{'default'} ],
			  [ 12 ], [ 16 ], [ 32 ],
			  [ "*", $text{'msdos_F_other'} ] ])." ".
	     &ui_textbox("msdos_F_other", undef, 4));
	&opt_input("msdos_i", "", 1);
	&opt_input("msdos_n", "", 0);
	&opt_input("msdos_r", "", 1);
	&opt_input("msdos_s", "sectors", 0);
	print &ui_table_row($text{'msdos_c'},
		&ui_yesno_radio("msdos_c", 0));
	}
elsif ($_[0] eq "minix") {
	&opt_input("minix_n", "", 1);
	&opt_input("minix_i", "", 0);
	&opt_input("minix_b", "", 1);
	print &ui_table_row($text{'minix_c'},
		&ui_yesno_radio("minix_c", 0));
	}
elsif ($_[0] eq "reiserfs") {
	print &ui_table_row($text{'reiserfs_force'},
		&ui_yesno_radio("reiserfs_f", 0));

	print &ui_table_row($text{'reiserfs_hash'},
		&ui_select("reiserfs_h", "",
			   [ [ "", $text{'default'} ],
			     [ "rupasov", "tea" ] ]));
	}
elsif ($_[0] =~ /^ext\d+$/) {
	&opt_input("ext2_b", $text{'bytes'}, 1);
	&opt_input("ext2_f", $text{'bytes'}, 0);
	&opt_input("ext2_i", "", 1);
	&opt_input("ext2_m", "%", 0);
	&opt_input("ext3_j", "MB", 1);
	print &ui_table_row($text{'ext2_c'},
		&ui_yesno_radio("ext2_c", 0));
	}
elsif ($_[0] eq "xfs") {
	print &ui_table_row($text{'xfs_force'},
		&ui_yesno_radio("xfs_f", 0));
	&opt_input("xfs_b", $text{'bytes'}, 0);
	}
elsif ($_[0] eq "jfs") {
	&opt_input("jfs_s", $text{'megabytes'}, 1);
	print &ui_table_row($text{'jfs_c'},
		&ui_yesno_radio("jfs_c", 0));
	}
elsif ($_[0] eq "fatx") {
	# Has no options!
	print &ui_table_row(undef, $text{'fatx_none'}, 4);
	}
elsif ($_[0] eq "btrfs") {
	&opt_input("btrfs_l", $text{'bytes'}, 0);
	&opt_input("btrfs_n", $text{'bytes'}, 0);
	&opt_input("btrfs_s", $text{'bytes'}, 0);
	}
}

# mkfs_parse(type, device)
# Returns a command to build a new filesystem of the given type on the
# given device. Options are taken from %in.
sub mkfs_parse
{
local($cmd);
if ($_[0] eq "msdos" || $_[0] eq "vfat") {
	$cmd = "mkfs -t $_[0]";
	$cmd .= &opt_check("msdos_ff", '[1-2]', "-f");
	if ($in{'msdos_F'} eq '*') {
		$in{'msdos_F_other'} =~ /^\d+$/ ||
			&error(&text('opt_error', $in{'msdos_F_other'},
						  $text{'msdos_F'}));
		$cmd .= " -F ".$in{'msdos_F_other'};
		}
	elsif ($in{'msdos_F'}) {
		$cmd .= " -F ".$in{'msdos_F'};
		}
	$cmd .= &opt_check("msdos_i", '[0-9a-f]{8}', "-i");
	$cmd .= &opt_check("msdos_n", '\S{1,11}', "-n");
	$cmd .= &opt_check("msdos_r", '\d+', "-r");
	$cmd .= &opt_check("msdos_s", '\d+', "-s");
	$cmd .= $in{'msdos_c'} ? " -c" : "";
	$cmd .= " $_[1]";
	}
elsif ($_[0] eq "minix") {
	local(@plist, $disk, $part, $i, @pinfo);
	$cmd = "mkfs -t minix";
	$cmd .= &opt_check("minix_n", '14|30', "-n ");
	$cmd .= &opt_check("minix_i", '\d+', "-i ");
	$cmd .= $in{'minix_c'} ? " -c" : "";
	$cmd .= &opt_check("minix_b", '\d+', " ");
	$cmd .= " $_[1]";
	}
elsif ($_[0] eq "reiserfs") {
	$cmd = "yes | mkreiserfs";
	$cmd .= " -f" if ($in{'reiserfs_f'});
	$cmd .= " -h $in{'reiserfs_h'}" if ($in{'reiserfs_h'});
	$cmd .= " $_[1]";
	}
elsif ($_[0] =~ /^ext\d+$/) {
	if (&has_command("mkfs.$_[0]")) {
		$cmd = "mkfs -t $_[0]";
		$cmd .= &opt_check("ext3_j", '\d+', "-j");
		}
	elsif ($_[0] eq "ext3" && &has_command("mke3fs")) {
		$cmd = "mke3fs";
		$cmd .= &opt_check("ext3_j", '\d+', "-j");
		}
	elsif ($_[0] eq "ext4" && &has_command("mke4fs")) {
		$cmd = "mke4fs";
		$cmd .= &opt_check("ext3_j", '\d+', "-j");
		}
	else {
		$cmd = "mkfs.ext2 -j";
		if (!$in{'ext3_j_def'}) {
			$in{'ext3_j'} =~ /^\d+$/ ||
				&error(&text('opt_error', $in{'ext3_j'},
					     $text{'ext3_j'}));
			$cmd .= " -J size=$in{'ext3_j'}";
			}
		}
	$cmd .= &opt_check("ext2_b", '\d+', "-b");
	$cmd .= &opt_check("ext2_f", '\d+', "-f");
	$cmd .= &opt_check("ext2_i", '\d{4,}', "-i");
	$cmd .= &opt_check("ext2_m", '\d+', "-m");
	$cmd .= $in{'ext2_c'} ? " -c" : "";
	$cmd .= " -q";
	$cmd .= " $_[1]";
	}
elsif ($_[0] eq "xfs") {
	$cmd = "mkfs -t $_[0]";
	$cmd .= " -f" if ($in{'xfs_f'});
	$cmd .= " -b size=$in{'xfs_b'}" if (!$in{'xfs_b_def'});
	$cmd .= " $_[1]";
	}
elsif ($_[0] eq "jfs") {
	$cmd = "mkfs -t $_[0] -q";
	$cmd .= &opt_check("jfs_s", '\d+', "-s");
	$cmd .= " -c" if ($in{'jfs_c'});
	$cmd .= " $_[1]";
	}
elsif ($_[0] eq "fatx") {
	$cmd = "mkfs -t $_[0] $_[1]";
	}
elsif ($_[0] eq "btrfs") {
	$cmd = "mkfs -t $_[0]";
	$cmd .= " -l $in{'btrfs_l'}" if (!$in{'btrfs_l_def'});
	$cmd .= " -n $in{'btrfs_n'}" if (!$in{'btrfs_n_def'});
	$cmd .= " -s $in{'btrfs_s'}" if (!$in{'btrfs_s_def'});
	$cmd .= " $_[1]";
	}
if (&has_command("partprobe")) {
	$cmd = "partprobe ; $cmd";
	}
return $cmd;
}

# can_tune(type)
# Returns 1 if this filesystem type can be tuned
sub can_tune
{
return $_[0] =~ /^ext\d+$/;
}

# tunefs_options(type)
# Output HTML for tuning options for some filesystem type
sub tunefs_options
{
if ($_[0] =~ /^ext\d+$/) {
	# Gaps between checks
	&opt_input("tunefs_c", "", 1);

	# Action on error
	print &ui_table_row($text{'tunefs_e'},
		&ui_radio("tunefs_e_def", 1,
			[ [ 1, $text{'opt_default'} ],
			  [ 0, &ui_select("tunefs_e", undef,
				[ [ "continue", $text{'tunefs_continue'} ],
				  [ "remount-ro", $text{'tunefs_remount'} ],
				  [ "panic", $text{'tunefs_panic'} ] ]) ] ]));

	# Reserved user
	print &ui_table_row($text{'tunefs_u'},
		&ui_opt_textbox("tunefs_u", undef, 13, $text{'opt_default'})." ".
		&user_chooser_button("tunefs_u", 0));

	# Reserved group
	print &ui_table_row($text{'tunefs_g'},
		&ui_opt_textbox("tunefs_g", undef, 13, $text{'opt_default'})." ".
		&group_chooser_button("tunefs_g", 0));

	# Reserved blocks
	&opt_input("tunefs_m", "%", 1);

	# Time between checks
	$tsel = &ui_select("tunefs_i_unit", undef,
			   [ [ "d", $text{'tunefs_days'} ],
			     [ "w", $text{'tunefs_weeks'} ],
			     [ "m", $text{'tunefs_months'} ] ]);
	&opt_input("tunefs_i", $tsel, 0);
	}
}

# tunefs_parse(type, device)
# Returns the tuning command based on user inputs
sub tunefs_parse
{
if ($_[0] =~ /^ext\d+$/) {
	$cmd = "tune2fs";
	$cmd .= &opt_check("tunefs_c", '\d+', "-c");
	$cmd .= $in{'tunefs_e_def'} ? "" : " -e$in{'tunefs_e'}";
	$cmd .= $in{'tunefs_u_def'} ? "" : " -u".getpwnam($in{'tunefs_u'});
	$cmd .= $in{'tunefs_g_def'} ? "" : " -g".getgrnam($in{'tunefs_g'});
	$cmd .= &opt_check("tunefs_m",'\d+',"-m");
	$cmd .= &opt_check("tunefs_i", '\d+', "-i").
		($in{'tunefs_i_def'} ? "" : $in{'tunefs_i_unit'});
	$cmd .= " $_[1]";
	}
return $cmd;
}

# need_reboot(disk)
# Returns 1 if a reboot is needed after changing the partitions on some disk
sub need_reboot
{
local $un = `uname -r`;
return $un =~ /^2\.0\./ || $un =~ /^1\./ || $un =~ /^0\./;
}

# device_status(device)
# Returns an array of  directory, type, mounted, module
sub device_status
{
@mounted = &foreign_call("mount", "list_mounted") if (!@mounted);
@mounts = &foreign_call("mount", "list_mounts") if (!@mounts);
local $label = &get_label($_[0]);
local $volid = &get_volid($_[0]);

local ($mounted) = grep { &same_file($_->[1], $_[0]) ||
			  $_->[1] eq "LABEL=$label" ||
			  $_->[1] eq "UUID=$volid" } @mounted;
local ($mount) = grep { &same_file($_->[1], $_[0]) ||
			$_->[1] eq "LABEL=$label" ||
			$_->[1] eq "UUID=$volid" } @mounts;
if ($mounted) { return ($mounted->[0], $mounted->[2], 1,
			&indexof($mount, @mounts),
			&indexof($mounted, @mounted)); }
elsif ($mount) { return ($mount->[0], $mount->[2], 0,
			 &indexof($mount, @mounts)); }
if ($raid_module) {
	my $raidconf = &foreign_call("raid", "get_raidtab") if (!$raidconf);
	foreach $c (@$raidconf) {
		foreach $d (&raid::find_value('device', $c->{'members'})) {
			return ( $c->{'value'}, "raid", 1, "raid" )
				if ($d eq $_[0]);
			}
		}
	}
if ($lvm_module) {
	if (!scalar(@physical_volumes)) {
		@physical_volumes = ();
		foreach $vg (&foreign_call("lvm", "list_volume_groups")) {
			push(@physical_volumes,
				&foreign_call("lvm", "list_physical_volumes",
						     $vg->{'name'}));
			}
		}
	foreach my $pv (@physical_volumes) {
		return ( $pv->{'vg'}, "lvm", 1, "lvm")
			if ($pv->{'device'} eq $_[0]);
		}
	}
if ($iscsi_server_module) {
	my $iscsiconf = &iscsi_server::get_iscsi_config();
	foreach my $c (@$iscsiconf) {
		if ($c->{'type'} eq 'extent' && $c->{'device'} eq $_[0]) {
			return ( $c->{'type'}.$c->{'num'}, "iscsi", 1,
				 "iscsi-server");
			}
		}
	}
if ($iscsi_target_module) {
	my $iscsiconf = &iscsi_target::get_iscsi_config();
	foreach my $t (&iscsi_target::find($iscsiconf, "Target")) {
		foreach my $l (&iscsi_target::find($t->{'members'}, "Lun")) {
			if ($l->{'value'} =~ /Path=([^, ]+)/ && $1 eq $_[0]) {
				return ( $t->{'value'}, "iscsi", 1,
					 "iscsi-target");
				}
			}
		}
	}
return ();
}

# device_status_link(directory, type, mounted, module)
# Converts the list returned by device_status to a link
sub device_status_link
{
my @stat = @_;
my $stat = "";
my $statdesc = $stat[0] =~ /^swap/ ? "<i>$text{'disk_vm'}</i>"
				   : "<tt>$stat[0]</tt>";
my $ret = $main::initial_module_name;
if ($ret !~ /fdisk$/) {
	$ret = $module_name;
	}
if ($stat[1] eq 'raid') {
	$stat = $statdesc;
	}
elsif ($stat[1] eq 'lvm') {
	if (&foreign_available("lvm")) {
		$stat = "<a href='../lvm/'>".
			"LVM VG $statdesc</a>";
		}
	else {
		$stat = "LVM VG $statdesc";
		}
	}
elsif ($stat[1] eq 'iscsi') {
	$stat = &text('disk_iscsi', $stat[0]);
	if (&foreign_available("iscsi-server")) {
		$stat = "<a href='../$stat[3]/'>$stat</a>";
		}
	}
elsif ($stat[0] && !&foreign_available("mount")) {
	$stat = $statdesc;
	}
elsif ($stat[0] && $stat[3] == -1) {
	$stat = "<a href='../mount/edit_mount.cgi?".
		"index=$stat[4]&temp=1&return=/$ret/'>".
		"$statdesc</a>";
	}
elsif ($stat[0]) {
	$stat = "<a href='../mount/edit_mount.cgi?".
		"index=$stat[3]&return=/$ret/'>".
		"$statdesc</a>";
	}
return $stat;
}

# can_fsck(type)
# Returns 1 if some filesystem type can fsck'd
sub can_fsck
{
return ($_[0] =~ /^ext\d+$/ && &has_command("fsck.$_[0]") ||
	$_[0] eq "minix" && &has_command("fsck.minix"));
}

# fsck_command(type, device)
# Returns the fsck command to unconditionally check a filesystem
sub fsck_command
{
if ($_[0] =~ /^ext\d+$/) {
	return "fsck -t $_[0] -p $_[1]";
	}
elsif ($_[0] eq "minix") {
	return "fsck -t minix -a $_[1]";
	}
}

# fsck_error(code)
# Returns a description of an exit code from fsck
sub fsck_error
{
return $text{"fsck_err$_[0]"} ? $text{"fsck_err$_[0]"}
			      : &text("fsck_unknown", $_[0]);
}

# partition_select(name, value, mode, [&found], [disk_regexp])
# Returns HTML for selecting a disk or partition
# mode 0 = floppies and disk partitions
#      1 = disks
#      2 = floppies and disks and disk partitions
#      3 = disk partitions
sub partition_select
{
local ($name, $value, $mode, $found, $diskre) = @_;
local $rv = "<select name=$_[0]>\n";
local @opts;
if (($mode == 0 || $mode == 2) &&
    (-r "/dev/fd0" || $value =~ /^\/dev\/fd[01]$/)) {
	push(@opts, [ '/dev/fd0', &text('select_fd', 0) ])
		if (!$diskre || '/dev/fd0' =~ /$diskre/);
	push(@opts, [ '/dev/fd1', &text('select_fd', 1) ])
		if (!$diskre || '/dev/fd1' =~ /$diskre/);
	${$found}++ if ($found && $value =~ /^\/dev\/fd[01]$/);
	}
local @dlist = &list_disks_partitions();
foreach my $d (@dlist) {
	local $dev = $d->{'device'};
	next if ($diskre && $dev !~ /$_[4]/);
	if ($mode == 1 || $mode == 2) {
		local $name = $d->{'desc'};
		$name .= " ($d->{'model'})" if ($d->{'model'});
		push(@opts, [ $dev, $name ]);
		${$found}++ if ($found && $dev eq $_[1]);
		}
	if ($mode == 0 || $mode == 2 || $mode == 3) {
		foreach $p (@{$d->{'parts'}}) {
			next if ($p->{'extended'});
			local $name = $p->{'desc'};
			$name .= " (".&tag_name($p->{'type'}).")"
				if (&tag_name($p->{'type'}));
			push(@opts, [ $p->{'device'}, $name ]);
			${$found}++ if ($found && $value eq $p->{'device'});
			}
		}
	}
return &ui_select($name, $value, \@opts, 1, 0, $value && !$found);
}

# label_select(name, value, &found)
# Returns HTML for selecting a filesystem label
sub label_select
{
local ($name, $value, $found) = @_;
local @opts;
local @dlist = &list_disks_partitions();
local $any;
foreach my $d (@dlist) {
	local $dev = $d->{'device'};
	foreach $p (@{$d->{'parts'}}) {
		next if ($p->{'type'} ne '83' &&
			 $p->{'type'} !~ /^ext/);
		local $label = &get_label($p->{'device'});
		next if (!$label);
		push(@opts, [ $label, $label." (".$p->{'desc'}.")" ]);
		${$found}++ if ($value eq $label && $found);
		$any++;
		}
	}
if (@opts) {
	return &ui_select($name, $value, \@opts, 1, 0, $value && !$found);
	}
else {
	return undef;
	}
}

# volid_select(name, value, &found)
# Returns HTML for selecting a filesystem UUID
sub volid_select
{
local ($name, $value, $found) = @_;
local @dlist = &list_disks_partitions();
local @opts;
foreach my $d (@dlist) {
	local $dev = $d->{'device'};
	foreach $p (@{$d->{'parts'}}) {
		next if ($p->{'type'} ne '83' && $p->{'type'} ne '82' &&
			 $p->{'type'} ne 'b' && $p->{'type'} ne 'c' &&
			 $p->{'type'} !~ /^(ext|xfs)/);
		local $volid = &get_volid($p->{'device'});
		next if (!$volid);
		push(@opts, [ $volid, "$volid ($p->{'desc'})" ]);
		${$found}++ if ($value eq $volid && $found);
		}
	}
if (@opts) {
	return &ui_select($name, $value, \@opts, 1, 0, $value && !$found);
	}
else {
	return undef;
	}
}

#############################################################################
# Internal functions
#############################################################################
sub open_fdisk
{
local $fpath = &check_fdisk();
my $cylarg;
if ($fpath =~ /\/fdisk/) {
	my $out = &backquote_command("$fpath -h 2>&1 </dev/null");
	if ($out =~ /-u\s+<size>/) {
		$cylarg = "-u=cylinders";
		}
	}
($fh, $fpid) = &foreign_call("proc", "pty_process_exec",
			     join(" ", $fpath, $cylarg, @_));
}

sub open_sfdisk
{
local $sfpath = &has_command("sfdisk");
($fh, $fpid) = &foreign_call("proc", "pty_process_exec", join(" ",$sfpath, @_));
}

sub check_fdisk
{
local $fpath = &has_command("fdisk");
&error(&text('open_error', "<tt>fdisk</tt>")) if (!$fpath);
return $fpath;
}

sub close_fdisk
{
close($fh); kill('TERM', $fpid);
}

sub wprint
{
syswrite($fh, $_[0], length($_[0]));
}

sub opt_input
{
print &ui_table_row($text{$_[0]},
	&ui_opt_textbox($_[0], undef, 6, $text{'opt_default'})." ".$_[1]);
}

sub opt_check
{
if ($in{"$_[0]_def"}) { return ""; }
elsif ($in{$_[0]} !~ /^$_[1]$/) {
	&error(&text('opt_error', $in{$_[0]}, $text{$_[0]}));
	}
else { return " $_[2] $in{$_[0]}"; }
}

%tags = ('0', 'Empty',
	 '1', 'FAT12',
	 '2', 'XENIX root',
	 '3', 'XENIX usr',
	 '4', 'FAT16 <32M',
	 '6', 'FAT16',
	 '7', 'NTFS',
	 '8', 'AIX',
	 '9', 'AIX bootable',
	 'a', 'OS/2 boot manager',
	 'b', 'Windows FAT32',
	 'c', 'Windows FAT32 LBA',
	 'e', 'Windows FAT16 LBA',
	'10', 'OPUS',
	'11', 'Hidden FAT12',
	'12', 'Compaq diagnostic',
	'14', 'Hidden FAT16 < 32M',
	'16', 'Hidden FAT16',
	'17', 'Hidden NTFS',
	'18', 'AST Windows swapfile',
	'1b', 'Hidden Windows FAT (1b)',
	'1c', 'Hidden Windows FAT (1c)',
	'1e', 'Hidden Windows FAT (1e)',
	'24', 'NEC DOS',
	'3c', 'PartitionMagic recovery',
	'40', 'Venix 80286',
	'41', 'PPC PReP boot',
	'42', 'SFS',
	'4d', 'QNX 4.x',
	'4e', 'QNX 4.x 2nd partition',
	'4f', 'QNX 4.x 3rd partition',
	'50', 'OnTrack DM',
	'51', 'OnTrack DM6 Aux1',
	'52', 'CP/M',
	'53', 'OnTrack DM6 Aux3',
	'54', 'OnTrack DM6',
	'55', 'EZ-Drive',
	'56', 'Golden Bow',
	'5c', 'Priam Edisk',
	'61', 'SpeedStor',
	'63', 'GNU HURD or SysV',
	'64', 'Novell Netware 286',
	'65', 'Novell Netware 386',
	'70', 'DiskSecure Multi-Boot',
	'75', 'PC/IX',
	'80', 'Old Minix',
	'81', 'Minix / Old Linux / Solaris',
	'82', 'Linux swap',
	'83', 'Linux',
	'84', 'OS/2 hidden C: drive',
	'85', 'Linux extended',
	'86', 'NTFS volume set (86)',
	'87', 'NTFS volume set (87)',
	'8e', 'Linux LVM',
	'93', 'Amoeba',
	'94', 'Amoeba BBT',
	'a0', 'IBM Thinkpad hibernation',
	'a5', 'BSD/386',
	'a6', 'OpenBSD',
	'a7', 'NeXTSTEP',
	'b7', 'BSDI filesystem',
	'b8', 'BSDI swap',
	'c1', 'DRDOS/sec FAT12',
	'c4', 'DRDOS/sec FAT16 <32M',
	'c6', 'DRDOS/sec FAT16',
	'c7', 'Syrinx',
	'db', 'CP/M / CTOS',
	'e1', 'DOS access',
	'e3', 'DOS read-only',
	'e4', 'SpeedStor',
	'eb', 'BeOS',
	'ee', 'GPT',
	'f1', 'SpeedStor',
	'f4', 'SpeedStor large partition',
	'f2', 'DOS secondary',
	'fd', 'Linux RAID',
	'fe', 'LANstep',
	'ff', 'BBT'
	);

%hidden_tags = (
	 '5', 'Extended',
	 'f', 'Windows extended LBA',
	);

%parted_tags = (
	'', 'None',
	'fat16', 'Windows FAT16',
	'fat32', 'Windows FAT32',
	'ext2', 'Linux EXT',
	'xfs', 'Linux XFS',
	'raid', 'Linux RAID',
	'HFS', 'MacOS HFS',
	'linux-swap', 'Linux Swap',
	'NTFS', 'Windows NTFS',
	'reiserfs', 'ReiserFS',
	'ufs', 'FreeBSD UFS',
	);
	
@space_type = ( '1', '4', '5', '6', 'b', 'c', 'e', '83' );

# can_edit_disk(device)
sub can_edit_disk
{
my ($device) = @_;
$device =~ s/\d+$//;
foreach (split(/\s+/, $access{'disks'})) {
        return 1 if ($_ eq "*" || $_ eq $device);
        }
return 0;
}

# disk_space(device, [mountpoint])
# Returns the amount of total and free space for some filesystem, or an
# empty array if not appropriate.
sub disk_space
{
local $w = $_[1] || $_[0];
local $out = `df -k '$w'`;
if ($out =~ /Mounted on\s*\n\s*\S+\s+(\S+)\s+\S+\s+(\S+)/i) {
	return ($1, $2);
	}
elsif ($out =~ /Mounted on\s*\n\S+\s*\n\s+(\S+)\s+\S+\s+(\S+)/i) {
	return ($1, $2);
	}
else {
	return ( );
	}
}

# supported_filesystems()
# Returns a list of filesystem types that can have mkfs_options called on them
sub supported_filesystems
{
local @fstypes = ( "ext2" );
push(@fstypes, "ext3") if (&has_command("mkfs.ext3") ||
			   &has_command("mke3fs") ||
			   `mkfs.ext2 -h 2>&1` =~ /\[-j\]/);
push(@fstypes, "ext4") if (&has_command("mkfs.ext4") ||
			   &has_command("mke4fs"));
push(@fstypes, "reiserfs") if (&has_command("mkreiserfs"));
push(@fstypes, "xfs") if (&has_command("mkfs.xfs"));
push(@fstypes, "jfs") if (&has_command("mkfs.jfs"));
push(@fstypes, "fatx") if (&has_command("mkfs.fatx"));
push(@fstypes, "btrfs") if (&has_command("mkfs.btrfs"));
push(@fstypes, "msdos");
push(@fstypes, "vfat");
push(@fstypes, "minix");
return @fstypes;
}

# get_label(device, [type])
# Returns the XFS or EXT label for some device's filesystem
sub get_label
{
local $label;
if ($has_e2label) {
	$label = `e2label $_[0] 2>&1`;
	chop($label);
	}
if (($? || $label !~ /\S/) && $has_xfs_db) {
	$label = undef;
	local $out = &backquote_with_timeout("xfs_db -x -p xfs_admin -c label -r $_[0] 2>&1", 5);
	$label = $1 if ($out =~ /label\s*=\s*"(.*)"/ &&
			$1 ne '(null)');
	}
if (($? || $label !~ /\S/) && $has_reiserfstune) {
	$label = undef;
	local $out = &backquote_command("reiserfstune $_[0]");
	if ($out =~ /LABEL:\s*(\S+)/) {
		$label = $1;
		}
	}
return $? || $label !~ /\S/ ? undef : $label;
}

# get_volid(device)
# Returns the UUID for some device's filesystem
sub get_volid
{
local ($device) = @_;
local $uuid;
if (-d $uuid_directory) {
	# Use UUID mapping directory
	opendir(DIR, $uuid_directory);
	foreach my $f (readdir(DIR)) {
		local $linkdest = &simplify_path(
			&resolve_links("$uuid_directory/$f"));
		if ($linkdest eq $device) {
			$uuid = $f;
			last;
			}
		}
	closedir(DIR);
	}
elsif ($has_volid) {
	# Use vol_id command
	local $out = &backquote_command(
			"vol_id ".quotemeta($device)." 2>&1", 1);
	if ($out =~ /ID_FS_UUID=(\S+)/) {
		$uuid = $1;
		}
	}
return $uuid;
}

# set_label(device, label, [type])
# Tries to set the label for some device's filesystem
sub set_label
{
if ($has_e2label && ($_[2] =~ /^ext[23]$/ || !$_[2])) {
	&system_logged("e2label '$_[0]' '$_[1]' >/dev/null 2>&1");
	return 1 if (!$?);
	}
if ($has_xfs_db && ($_[2] eq "xfs" || !$_[2])) {
	&system_logged("xfs_db -x -p xfs_admin -c \"label $_[1]\" $_[0] >/dev/null 2>&1");
	return 1 if (!$?);
	}
return 0;
}

# set_name(&disk, &partition, name)
# Sets the name of a partition, for partition types that support it
sub set_name
{
my ($dinfo, $pinfo, $name) = @_;
my $cmd = "parted -s ".$dinfo->{'device'}." name ".$pinfo->{'number'}." ";
if ($name) {
	$cmd .= quotemeta($name);
	}
else {
	$cmd .= " '\"\"'";
	}
my $out = &backquote_logged("$cmd </dev/null 2>&1");
if ($?) {
	&error("$cmd failed : $out");
	}
}

# set_partition_table(device, table-type)
# Wipe and re-create the partition table on some disk
sub set_partition_table
{
my ($disk, $table) = @_;
my $cmd = "parted -s ".$disk." mktable ".$table;
my $out = &backquote_logged("$cmd </dev/null 2>&1");
if ($?) {
	&error("$cmd failed : $out");
	}
}

# supports_label(&partition)
# Returns 1 if the label can be set on a partition
sub supports_label
{
my ($part) = @_;
return $part->{'type'} eq '83' || $part->{'type'} eq 'ext2';
}

# supports_name(&disk)
# Returns 1 if the name can be set on a disk's partitions
sub supports_name
{
my ($disk) = @_;
return $disk->{'table'} eq 'gpt';
}

# supports_hdparm(&disk)
sub supports_hdparm
{
local ($d) = @_;
return $d->{'type'} eq 'ide' || $d->{'type'} eq 'scsi' && $d->{'model'} =~ /ATA/;
}

# supports_relabel(&disk)
# Return 1 if a disk can have it's partition table re-written
sub supports_relabel
{
return $has_parted ? 1 : 0;
}

# supports_smart(&disk)
sub supports_smart
{
return &foreign_installed("smart-status") &&
       &foreign_available("smart-status");
}

# supports_extended(&disk)
# Return 1 if some disk can support extended partitions
sub supports_extended
{
my ($disk) = @_;
return $disk->{'label'} eq 'msdos' ? 1 : 0;
}

# list_table_types(&disk)
# Returns the list of supported partition table types for a disk
sub list_table_types
{
if ($has_parted) {
	return ( 'msdos', 'gpt', 'bsd', 'dvh', 'loop', 'mac', 'pc98', 'sun' );
	}
else {
	return ( 'msdos' );
	}
}

# get_parted_version()
# Returns the version number of parted that is installed
sub get_parted_version
{
my $out = &backquote_command("parted -v 2>&1 </dev/null");
return $out =~ /parted.*\s([0-9\.]+)/i ? $1 : undef;
}

# identify_disk(&disk)
# Blinks the activity LED of the drive sixty times
sub identify_disk
{
local ($d) = @_;
$count = 1;
while ($count <= 60) {
        &system_logged("dd if=".quotemeta($d->{'device'}).
		       " of=/dev/null bs=10M count=1");
	sleep(1);
	print "$count ";
	$count ++;
	}
}

1;
