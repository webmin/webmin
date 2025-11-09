BEGIN { push(@INC, ".."); }
use WebminCore;
init_config();
foreign_require("mount", "mount-lib.pl");
foreign_require("fdisk", "fdisk-lib.pl");

#---------------------------------------------------------------------
# Helper: Cache mount info
# Returns a hash reference of device => mount point and an arrayref
# containing mount entries.
sub get_all_mount_points_cached {
    my %mount_info;
    my @mount_list = mount::list_mounted();
    foreach my $m (@mount_list) {
        $mount_info{$m->[0]} = $m->[1];
    }
    my $swapinfo = `swapinfo -k 2>/dev/null`;
    foreach my $line (split(/\n/, $swapinfo)) {
        if ($line =~ /^(\/dev\/\S+)\s+\d+\s+\d+\s+\d+/) {
            $mount_info{$1} = "swap";
        }
    }
    # ZFS, GEOM, glabel, geli – remain the same as the original.
    if (has_command("zpool")) {
        my $zpool_out = `zpool status 2>/dev/null`;
        my $current_pool = "";
        foreach my $line (split(/\n/, $zpool_out)) {
            if ($line =~ /^\s*pool:\s+(\S+)/) {
                $current_pool = $1;
            }
            elsif ($line =~ /^\s*(\/dev\/\S+)/) {
                my $dev = $1;
                $mount_info{$dev} = "ZFS pool: $current_pool";
            }
        }
    }
    if (has_command("geom")) {
        # gmirror
        my $gmirror_out = `gmirror status 2>/dev/null`;
        my $current_mirror = "";
        foreach my $line (split(/\n/, $gmirror_out)) {
            if ($line =~ /^(\S+):/) {
                $current_mirror = $1;
            }
            elsif ($line =~ /^\s*(\/dev\/\S+)/) {
                my $dev = $1;
                $mount_info{$dev} = "gmirror: $current_mirror";
            }
        }
        # gstripe
        my $gstripe_out = `gstripe status 2>/dev/null`;
        my $current_stripe = "";
        foreach my $line (split(/\n/, $gstripe_out)) {
            if ($line =~ /^(\S+):/) {
                $current_stripe = $1;
            }
            elsif ($line =~ /^\s*(\/dev\/\S+)/) {
                my $dev = $1;
                $mount_info{$dev} = "gstripe: $current_stripe";
            }
        }
        # graid
        my $graid_out = `graid status 2>/dev/null`;
        my $current_raid = "";
        foreach my $line (split(/\n/, $graid_out)) {
            if ($line =~ /^(\S+):/) {
                $current_raid = $1;
            }
            elsif ($line =~ /^\s*(\/dev\/\S+)/) {
                my $dev = $1;
                $mount_info{$dev} = "graid: $current_raid";
            }
        }
    }
    if (has_command("glabel")) {
        my $glabel_out = `glabel status 2>/dev/null`;
        foreach my $line (split(/\n/, $glabel_out)) {
            if ($line =~ /^\s*(\S+)\s+(\S+)\s+(\S+)/) {
                my $label = $1;
                my $dev = $3;
                if ($dev =~ /^\/dev\//) {
                    $mount_info{$dev} = "glabel: $label";
                }
            }
        }
    }
    if (has_command("geli")) {
        my $geli_out = `geli status 2>/dev/null`;
        foreach my $line (split(/\n/, $geli_out)) {
            if ($line =~ /^(\/dev\/\S+)\s+/) {
                my $dev = $1;
                $mount_info{$dev} = "geli encrypted";
            }
        }
    }
    return (\%mount_info, \@mount_list);
}

#---------------------------------------------------------------------
# Helper: Get file statistics for a device (cached per device)
sub get_dev_stat {
    my ($dev) = @_;
    if (-e $dev) {
        my @st = stat($dev);
        if (@st) {
            my $size = $st[7];
            my $blocks = int($size / 512);
            return ($size, $blocks);
        }
    }
    return (undef, undef);
}

#---------------------------------------------------------------------
# is_boot_partition()
# Accepts a partition hash and an optional mount list to avoid re-calling mount::list_mounted()
sub is_boot_partition {
    my ($part, $mount_list_ref) = @_;
    return 1 if ($part->{'type'} eq 'freebsd-boot' or $part->{'type'} eq 'efi');
    return 1 if ($part->{'active'});
    my @mounts = $mount_list_ref ? @$mount_list_ref : mount::list_mounted();
    foreach my $m (@mounts) {
        if ($m->[1] eq '/boot' and $m->[0] eq $part->{'device'}) {
            return 1;
        }
    }
    if ($part->{'type'} eq 'freebsd-zfs') {
        my $out = backquote_command("zpool get bootfs 2>/dev/null");
        if ($out =~ /\s+bootfs\s+\S+\/boot\s+/) {
            my $pool_out = backquote_command("zpool status 2>/dev/null");
            if ($pool_out =~ /\Q$part->{'device'}\E/) {
                return 1;
            }
        }
    }
    return 0;
}

#---------------------------------------------------------------------
# list_disks_partitions()
# Returns a list of all disks, slices and partitions (optimized)
sub list_disks_partitions {
    my @results;
    my %dev_stat_cache;  # cache stat info per /dev device
    my @disk_devices;

    # Get disk devices from /dev directory
    if (opendir(my $dh, "/dev")) {
        my @all_devs = readdir($dh);
        closedir($dh);
        foreach my $dev (@all_devs) {
            if ($dev =~ /^(ada|ad|da|amrd|nvd|vtbd)(\d+)$/) {
                push(@disk_devices, $dev);
            }
        }
    }
    # Fallback: sysctl
    if (!@disk_devices) {
        my $sysctl_out = `sysctl -n kern.disks 2>/dev/null`;
        if ($sysctl_out) {
            chomp($sysctl_out);
            @disk_devices = split(/\s+/, $sysctl_out);
        }
    }
    # Fallback: dmesg
    if (!@disk_devices) {
        my $dmesg_out = `dmesg | grep -E '(ada|ad|da|amrd|nvd|vtbd)[0-9]+:' 2>/dev/null`;
        while ($dmesg_out =~ /\b(ada|ad|da|amrd|nvd|vtbd)(\d+):/g) {
            my $disk = "$1$2";
            push(@disk_devices, $disk) if (-e "/dev/$disk");
        }
    }
    # Fallback: geom
    if (!@disk_devices) {
        my $geom_out = `geom disk list 2>/dev/null`;
        while ($geom_out =~ /Name:\s+(\S+)/g) {
            my $disk = $1;
            push(@disk_devices, $disk) if (-e "/dev/$disk");
        }
    }

    # Get mount information once for all devices
    my ($mount_info, $mount_list) = get_all_mount_points_cached();

    foreach my $disk (@disk_devices) {
        my $disk_device = "/dev/$disk";
        my $diskinfo = { 'device' => $disk_device, 'name' => $disk };
        # Determine sector size once per disk (4K-aware)
        my $sectorsz = get_disk_sectorsize($disk_device) || 512;
        $diskinfo->{'sectorsize'} = $sectorsz;

        # Cache stat information for the disk device
        unless (exists $dev_stat_cache{$disk_device}) {
            my ($size, $blocks) = get_dev_stat($disk_device);
            $dev_stat_cache{$disk_device} = (defined $size) ? [$size, $blocks || 0] : [0, 0];
        }
        my ($size, $blocks_cached) = @{ $dev_stat_cache{$disk_device} };
        if ($size > 0) {
            $diskinfo->{'size'} = $size;
            $diskinfo->{'blocks'} = int($size / $sectorsz);
        } else {
            my $diskinfo_out = `diskinfo $disk 2>/dev/null`;
            if ($diskinfo_out =~ /^(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)/) {
                $diskinfo->{'size'} = $1;
                $diskinfo->{'blocks'} = int($1 / $sectorsz);
                $diskinfo->{'cylinders'} = $2;
                $diskinfo->{'heads'} = $3;
                $diskinfo->{'sectors'} = $4;
                if (defined $5 && $5 ne '' && $5 !~ /^\d+$/) {
                    $diskinfo->{'model'} = $5;
                }
            }
            if (!$diskinfo->{'size'}) {
                my $diskinfo_v_out = `diskinfo -v $disk 2>/dev/null`;
                if ($diskinfo_v_out =~ /sectorsize:\s*(\d+)/i) {
                    $sectorsz = $1;
                    $diskinfo->{'sectorsize'} = $sectorsz;
                }
                if ($diskinfo_v_out =~ /mediasize in bytes:\s+(\d+)/i) {
                    $diskinfo->{'size'} = $1;
                    $diskinfo->{'blocks'} = int($1 / $sectorsz);
                }
                if ($diskinfo_v_out =~ /descr:\s+(.*)/) {
                    $diskinfo->{'model'} = $1;
                }
            }
            if (!$diskinfo->{'model'}) {
                my $cam_id_out = `camcontrol identify $disk 2>/dev/null`;
                if ($cam_id_out =~ /model\s+(.*)/i) {
                    my $m = $1;
                    $m =~ s/^\s+|\s+$//g;
                    $diskinfo->{'model'} = $m;
                }
            }
            if (!$diskinfo->{'model'}) {
                my $inq_out = `camcontrol inquiry $disk 2>/dev/null`;
                if ($inq_out =~ /<([^>]+)>/) {
                    $diskinfo->{'model'} = $1;
                } else {
                    my ($vendor)  = ($inq_out =~ /Vendor:\s*(\S.*?)(?:\s{2,}|$)/i);
                    my ($product) = ($inq_out =~ /Product:\s*(\S.*?)(?:\s{2,}|$)/i);
                    if ($vendor || $product) {
                        $diskinfo->{'model'} = join(' ', grep { defined && length } ($vendor, $product));
                    }
                }
            }
            if (!$diskinfo->{'model'}) {
                my $geom = get_detailed_disk_info($disk_device);
                if ($geom && $geom->{'descr'}) {
                    $diskinfo->{'model'} = $geom->{'descr'};
                } elsif ($geom && $geom->{'ident'}) {
                    $diskinfo->{'model'} = $geom->{'ident'};
                }
            }
            # If size still not known, try GEOM mediasize
            if (!$diskinfo->{'size'}) {
                my $geom2 = get_detailed_disk_info($disk_device);
                if ($geom2 && $geom2->{'mediasize_bytes'}) {
                    $diskinfo->{'size'} = $geom2->{'mediasize_bytes'};
                    $diskinfo->{'blocks'} = int($diskinfo->{'size'} / ($diskinfo->{'sectorsize'} || 512));
                }
            }
        }
        # Determine disk type
        if ($disk =~ /^ada/ or $disk =~ /^ad/) {
            $diskinfo->{'type'} = 'ide';
        } elsif ($disk =~ /^da/) {
            $diskinfo->{'type'} = 'scsi';
        } elsif ($disk =~ /^amrd/) {
            $diskinfo->{'type'} = 'memdisk';
        } elsif ($disk =~ /^nvd/) {
            $diskinfo->{'type'} = 'nvme';
        } elsif ($disk =~ /^vtbd/) {
            $diskinfo->{'type'} = 'virtio';
        }

        # Process slices and partitions
        $diskinfo->{'slices'} = [];
        if (has_command("gpart")) {
            my $gpart_out = `gpart show $disk 2>/dev/null`;
            my @lines = split(/\n/, $gpart_out);
            my $in_disk = 0;
            my $disk_scheme = undef;  # GPT, MBR, etc.
            foreach my $line (@lines) {
                if ($line =~ /=>/) {
                    $in_disk = 1;
                    # Try to extract scheme from header line
                    if ($line =~ /=>.*?\b$disk\b\s+(\S+)/) {
                        $disk_scheme = $1;
                    }
                    next;
                }
                if ($in_disk and $line =~ /^\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)/) {
                    my ($start, $num_blocks, $name_or_idx, $raw_type) = ($1, $2, $3, $4);
                    next if ($name_or_idx eq '-' or $raw_type eq 'free');
                    my $slice_type = ($raw_type eq '-') ? "freebsd" : $raw_type;

                    # Determine slice index and device name
                    my ($slice_index, $slice_devname);
                    if ($name_or_idx =~ /^$disk(?:p|s)(\d+)$/) {
                        $slice_index  = $1;
                        $slice_devname = $name_or_idx;
                    } elsif ($name_or_idx =~ /^\d+$/) {
                        $slice_index = $name_or_idx;
                        my $sep = (defined $disk_scheme && $disk_scheme =~ /GPT/i) ? 'p' : 's';
                        $slice_devname = $disk . $sep . $slice_index;
                    } else {
                        # Fallback: use as provided
                        $slice_devname = $name_or_idx;
                        # Try to extract index from suffix if possible
                        ($slice_index) = ($slice_devname =~ /(?:p|s)(\d+)$/);
                        $slice_index ||= $name_or_idx;
                    }
                    my $slice_device = "/dev/$slice_devname";

                    my $slice = {
                        'number'      => $slice_index,
                        'startblock'  => $start,
                        'blocks'      => $num_blocks,
                        'size'        => $num_blocks * $sectorsz,
                        'type'        => $slice_type,
                        'device'      => $slice_device,
                        'parts'       => []
                    };
                    $slice->{'used'} = $mount_info{$slice_device};

                    # Get partitions for this slice once, using the correct provider name
                    my $gpart_slice_out = `gpart show $slice_devname 2>/dev/null`;
                    my @slice_lines = split(/\n/, $gpart_slice_out);
                    my $in_slice = 0;
                    my $slice_scheme;
                    foreach my $slice_line (@slice_lines) {
                        if ($slice_line =~ /=>.*?\s+$slice_devname\s+(\S+)/) {
                            $in_slice = 1;
                            $slice_scheme = $1;  # e.g., BSD, GPT
                            next;
                        }
                        if ($in_slice and $slice_line =~ /^\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)/) {
                            my ($p_start, $p_blocks, $part_idx_or_name, $raw_ptype) = ($1, $2, $3, $4);
                            next if ($part_idx_or_name eq '-' or $raw_ptype eq 'free');
                            my $part_type = ($raw_ptype eq '-' and $part_idx_or_name ne '-') ? "freebsd-ufs" : $raw_ptype;
                            # For BSD disklabel, third column is index (1-based), convert to letter
                            my ($part_letter, $part_device);
                            if ($slice_scheme && $slice_scheme =~ /BSD/i && $part_idx_or_name =~ /^\d+$/) {
                                my $idx = int($part_idx_or_name);
                                $part_letter = chr(ord('a') + $idx - 1);  # 1 -> 'a', 2 -> 'b', etc.
                                $part_device = $slice_device . $part_letter;
                            } else {
                                # For other schemes or if already a name
                                $part_device = "/dev/$part_idx_or_name";
                                $part_letter = substr($part_idx_or_name, -1);
                            }
                            my $part = {
                                'letter'      => $part_letter,
                                'startblock'  => $p_start,
                                'blocks'      => $p_blocks,
                                'size'        => $p_blocks * $sectorsz,
                                'type'        => $part_type,
                                'device'      => $part_device,
                            };
                            $part->{'used'} = $mount_info{$part_device};
                            push(@{$slice->{'parts'}}, $part);
                        }
                    }
                    push(@{$diskinfo->{'slices'}}, $slice);
                }
            }
        }
        else {
            # If no slices found with gpart, use fdisk if available (similar caching ideas apply)
            if (has_command("fdisk")) {
                my $fdisk_out = `fdisk /dev/$disk 2>/dev/null`;
                foreach my $line (split(/\n/, $fdisk_out)) {
                    if ($line =~ /^\s*(\d+):\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/) {
                        my $slice_device = "/dev/${disk}s$1";
                        my $slice = {
                            'number'      => $1,
                            'startblock'  => $2,
                            'blocks'      => ($4 - $2 + 1),
                            'size'        => ($4 - $2 + 1) * $sectorsz,
                            'type'        => $5,
                            'device'      => $slice_device,
                            'parts'       => []
                        };
                        $slice->{'used'} = $mount_info{$slice_device};
                        my $disklabel_out = `disklabel -r $slice_device 2>/dev/null`;
                        foreach my $label_line (split(/\n/, $disklabel_out)) {
                            if ($label_line =~ /^(\s*)([a-h]):\s+(\d+)\s+(\d+)\s+(\S+)/) {
                                my $part_device = "${slice_device}$2";
                                my $part = {
                                    'letter'     => $2,
                                    'startblock' => $3,
                                    'blocks'     => $4,
                                    'size'       => $4 * $sectorsz,
                                    'type'       => $5,
                                    'device'     => $part_device
                                };
                                $part->{'used'} = $mount_info{$part_device};
                                push(@{$slice->{'parts'}}, $part);
                            }
                        }
                        push(@{$diskinfo->{'slices'}}, $slice);
                    }
                }
            }
        }
        # If size was not determined, estimate from slices if available
        if (!$diskinfo->{'size'} and @{$diskinfo->{'slices'}}) {
            my $total_size = 0;
            $total_size += $_->{'size'} for @{$diskinfo->{'slices'}};
            if ($total_size > 0) {
                $diskinfo->{'size'} = $total_size;
                $diskinfo->{'blocks'} = int($total_size / ($diskinfo->{'sectorsize'} || 512));
            }
        }
        # Finally, add this disk (dummy size set if necessary)
        if ($diskinfo->{'size'} or -e $disk_device) {
            $diskinfo->{'size'} = $diskinfo->{'size'} || 0;
            $diskinfo->{'blocks'} = $diskinfo->{'blocks'} || 0;
            push(@results, $diskinfo);
        }
    }
    return @results;
}

# check_fdisk() – unchanged
sub check_fdisk {
    if (!has_command("fdisk") and !has_command("gpart")) {
        return text('index_efdisk', "<tt>fdisk</tt>", "<tt>gpart</tt>");
    }
    return undef;
}

# is_using_gpart()
sub is_using_gpart {
    return has_command("gpart") ? 1 : 0;
}

# disk_name(device) – extracts name from /dev/device
sub disk_name {
    my ($device) = @_;
    $device =~ s/^\/dev\///;
    return $device;
}

# slice_name(slice)
sub slice_name {
    my ($slice) = @_;
    if ($slice->{'device'} =~ /\/dev\/(\S+)/) {
        return $1;
    }
    return $slice->{'number'};
}

# slice_number(slice)
sub slice_number {
    my ($slice) = @_;
    if ($slice->{'device'} =~ /\/dev\/\S+s(\d+)/) {
        return $1;
    }
    if ($slice->{'device'} =~ /\/dev\/\S+p(\d+)/) {
        return $1;
    }
    return $slice->{'number'};
}


#---------------------------------------------------------------------
# Filesystem command generation and slice/partition modification functions
sub create_slice {
    my ($disk, $slice) = @_;
    my $cmd;
    if (is_using_gpart()) {
        # Ensure a partitioning scheme exists (default to MBR for non-GPT, GPT if new) before adding
        my $base = disk_name($disk->{'device'});
        my $ds = get_disk_structure($base);
        my $scheme = 'MBR';  # default for existing disks or when type suggests MBR
        if (!$ds || !$ds->{'scheme'}) {
            # No scheme exists - decide based on partition type
            if ($slice->{'type'} =~ /^(freebsd|fat32|ntfs|linux)$/i) {
                $scheme = 'MBR';
            } else {
                $scheme = 'GPT';
            }
            my $init = "gpart create -s $scheme $base";
            my $init_out = `$init 2>&1`;
            if ($? != 0 && $init_out !~ /File exists|already exists/i) {
                return $init_out;
            }
            # Refresh disk structure after creation
            $ds = get_disk_structure($base);
        } else {
            $scheme = $ds->{'scheme'};
        }
        $cmd = "gpart add -t " . $slice->{'type'};
        $cmd .= " -b $slice->{'startblock'}" if ($slice->{'startblock'});
        $cmd .= " -s $slice->{'blocks'}"   if ($slice->{'blocks'});
        $cmd .= " " . $base;
        my $out = `$cmd 2>&1`;
        if ($?) {
            return $out;
        }
        # After successful creation, populate the device field for the slice
        # Determine the separator based on scheme
        my $sep = ($scheme =~ /GPT/i) ? 'p' : 's';
        my $slice_num = $slice->{'number'};
        $slice->{'device'} = "/dev/${base}${sep}${slice_num}";
        return undef;
    } else {
        $cmd = "fdisk -a";
        $cmd .= " -s $slice->{'number'}"    if ($slice->{'number'});
        $cmd .= " -b $slice->{'startblock'}"  if ($slice->{'startblock'});
        $cmd .= " -s $slice->{'blocks'}"      if ($slice->{'blocks'});
        $cmd .= " -t $slice->{'type'} "       . $disk->{'device'};
        my $out = `$cmd 2>&1`;
        if ($?) {
            return $out;
        }
        # Populate device field
        my $base = disk_name($disk->{'device'});
        $slice->{'device'} = "/dev/${base}s" . $slice->{'number'};
        return undef;
    }
}

sub delete_slice {
    my ($disk, $slice) = @_;
    if (is_boot_partition($slice)) { return $text{'slice_eboot'}; }
    foreach my $p (@{$slice->{'parts'}}) {
        if (is_boot_partition($p)) { return $text{'slice_eboot'}; }
    }
    my $cmd;
    if (is_using_gpart()) {
        $cmd = "gpart delete -i " . slice_number($slice) . " " . disk_name($disk->{'device'});
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    } else {
        $cmd = "fdisk -d " . $slice->{'number'} . " " . $disk->{'device'};
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    }
}

sub delete_partition {
    my ($disk, $slice, $part) = @_;
    if (is_boot_partition($part)) { return $text{'part_eboot'}; }
    my $cmd;
    if (is_using_gpart()) {
        # BSD disklabel uses 1-based indexing: 'a' = 1, 'b' = 2, etc.
        my $idx = (ord($part->{'letter'}) - ord('a')) + 1;
        $cmd = "gpart delete -i $idx " . slice_name($slice);
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    } else {
        $cmd = "disklabel -r -w -d $part->{'letter'} " . $slice->{'device'};
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    }
}

sub modify_slice {
    my ($disk, $oldslice, $slice, $part) = @_;
    if (is_boot_partition($part)) { return $text{'part_eboot'}; }
    foreach my $p (@{$slice->{'parts'}}) {
        if (is_boot_partition($p)) { return $text{'slice_eboot'}; }
    }
    my $cmd;
    if (is_using_gpart()) {
        $cmd = "gpart modify -i " . slice_number($slice) . " -t " . $slice->{'type'} . " " . disk_name($disk->{'device'});
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    } else {
        $cmd = "fdisk -a -s " . $slice->{'number'} . " -t " . $slice->{'type'} . " " . $disk->{'device'};
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    }
}

sub save_partition {
    my ($disk, $slice, $part) = @_;
    my $cmd;
    if (is_using_gpart()) {
        my $provider = slice_name($slice);
        # Detect if this provider is a BSD label (sub-partitions) or GPT/MBR
        my $show = backquote_command("gpart show $provider 2>&1");
        if ($show =~ /\bBSD\b/) {
            # Inner BSD label: index is 1-based a->1, b->2, etc. Only FreeBSD partition types are valid here.
            my $idx = (ord($part->{'letter'}) - ord('a')) + 1;
            $cmd = "gpart modify -i $idx -t " . $part->{'type'} . " $provider";
        } else {
            # Not a BSD label; modifying a top-level partition by letter is invalid. Return an error with guidance.
            return "Invalid operation: attempting to modify non-BSD sub-partition by letter. Use slice editing for top-level partitions.";
        }
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    } else {
        $cmd = "disklabel -r -w -p " . $part->{'letter'} . " -t " . $part->{'type'} . " " . $slice->{'device'};
        my $out = `$cmd 2>&1`;
        return ($?) ? $out : undef;
    }
}

# Create a new BSD partition inside an MBR slice (gpart BSD label)
sub create_partition {
    my ($disk, $slice, $part) = @_;
    if (!is_using_gpart()) {
        # Legacy path would use disklabel; not implemented here
        return "Legacy disklabel creation not supported";
    }
    my $prov = slice_name($slice);
    # Ensure BSD label exists on the slice
    my $show = backquote_command("gpart show $prov 2>&1");
    if ($show !~ /\bBSD\b/) {
        my $init_err = initialize_slice($disk, $slice);
        return $init_err if ($init_err);
        # Refresh the show output after initialization
        $show = backquote_command("gpart show $prov 2>&1");
    }
    # Compute 1-based index
    my $idx = (ord($part->{'letter'}) - ord('a')) + 1;
    # For BSD disklabel, start blocks are ALWAYS slice-relative
    # BSD partitions use 0-based addressing within the slice
    my $start_rel = $part->{'startblock'};
    my $blocks = $part->{'blocks'};
    my $cmd = "gpart add -i $idx -t $part->{'type'}";
    $cmd .= " -b $start_rel" if (defined $start_rel && $start_rel > 0);
    $cmd .= " -s $blocks"     if (defined $blocks     && $blocks > 0);
    $cmd .= " $prov";
    my $out = `$cmd 2>&1`;
    if ($?) {
        return $out;
    }
    # Populate the device field for the partition
    $part->{'device'} = $slice->{'device'} . $part->{'letter'};
    return undef;
}

sub get_create_filesystem_command {
    my ($disk, $slice, $part, $options) = @_;
    my $device = $part ? $part->{'device'} : $slice->{'device'};
    my @cmd = ("newfs");
    if (defined $options->{'free'} && $options->{'free'} =~ /^\d+$/) {
        push(@cmd, "-m", $options->{'free'});
    }
    if (defined $options->{'label'} && length $options->{'label'}) {
        push(@cmd, "-L", quote_path($options->{'label'}));
    }
    push(@cmd, "-t") if ($options->{'trim'});
    push(@cmd, quote_path($device));
    return join(" ", @cmd);
}

# Helper to set a GPT or BSD partition label after filesystem creation
sub set_partition_label {
    my (%args) = @_;
    my $disk  = $args{'disk'};
    my $slice = $args{'slice'};
    my $part  = $args{'part'};   # optional
    my $label = $args{'label'};
    return if (!defined $label || $label eq '');
    my $base = $disk->{'device'}; $base =~ s{^/dev/}{};
    my $ds = get_disk_structure($base);
    # GPT: label at disk level via gpart modify
    if ($ds && $ds->{'scheme'} && $ds->{'scheme'} =~ /GPT/i) {
        my $idx = $part ? undef : $slice->{'number'}; # slice is a GPT partition
        if ($idx) {
            my $cmd = "gpart modify -i $idx -l " . quote_path($label) . " $base";
            my $out = `$cmd 2>&1`;
            return ($? ? $out : undef);
        }
        return undef;
    }
    # MBR: use glabel for slice-level or partition-level labels
    my $device = $part ? $part->{'device'} : $slice->{'device'};
    if ($device && has_command('glabel')) {
        # Remove existing glabel if present, then add new one
        my $existing = backquote_command("glabel status 2>/dev/null | grep " . quote_path($device));
        if ($existing =~ /^(\S+)\s+/) {
            my $old_label = $1;
            my $destroy_out = `glabel destroy $old_label 2>&1`;
        }
        my $cmd = "glabel label " . quote_path($label) . " " . quote_path($device);
        my $out = `$cmd 2>&1`;
        return ($? ? $out : undef);
    }
    return undef;
}

sub remove_partition_label {
    my (%args) = @_;
    my $disk  = $args{'disk'};
    my $slice = $args{'slice'};
    my $part  = $args{'part'};
    my $base = $disk->{'device'}; $base =~ s{^/dev/}{};
    my $ds = get_disk_structure($base);
    # GPT: remove label via gpart modify -l ""
    if ($ds && $ds->{'scheme'} && $ds->{'scheme'} =~ /GPT/i) {
        my $idx = $part ? undef : $slice->{'number'};
        if ($idx) {
            my $cmd = "gpart modify -i $idx -l \"\" $base";
            my $out = `$cmd 2>&1`;
            return ($? ? $out : undef);
        }
        return undef;
    }
    # MBR: remove glabel
    my $device = $part ? $part->{'device'} : $slice->{'device'};
    if ($device && has_command('glabel')) {
        my $existing = backquote_command("glabel status 2>/dev/null | grep " . quote_path($device));
        if ($existing =~ /^(\S+)\s+/) {
            my $label = $1;
            my $cmd = "glabel destroy $label";
            my $out = `$cmd 2>&1`;
            return ($? ? $out : undef);
        }
    }
    return undef;
}

sub preferred_device_path {
    my ($device) = @_;
    return $device unless $device;
    # Check for GPT label first
    if (-e "/dev/gpt") {
        my $gpt_label = backquote_command("gpart list 2>/dev/null | grep -A 10 " . quote_path($device) . " | grep 'label:' | head -1");
        if ($gpt_label =~ /label:\s*(\S+)/ && $1 ne '(null)') {
            my $label_path = "/dev/gpt/$1";
            return $label_path if (-e $label_path);
        }
    }
    # Check for glabel label
    if (has_command('glabel')) {
        my $glabel_out = backquote_command("glabel status 2>/dev/null");
        foreach my $line (split(/\n/, $glabel_out)) {
            if ($line =~ /^(\S+)\s+\S+\s+(.+)$/) {
                my ($label, $provider) = ($1, $2);
                $provider =~ s/^\s+|\s+$//g;
                if ($provider eq $device || "/dev/$provider" eq $device) {
                    my $label_path = "/dev/label/$label";
                    return $label_path if (-e $label_path);
                }
            }
        }
    }
    # Check for UFS label
    my $ufs_label = backquote_command("tunefs -p $device 2>/dev/null | grep 'volume label'");
    if ($ufs_label =~ /volume label.*\[([^\]]+)\]/ && $1 ne '') {
        my $label_path = "/dev/ufs/$1";
        return $label_path if (-e $label_path);
    }
    # Default: return original device
    return $device;
}

sub detect_filesystem_type {
    my ($device, $hint) = @_;
    my $t;
    if (has_command('fstyp')) {
        $t = backquote_command("fstyp " . quote_path($device) . " 2>/dev/null");
        $t =~ s/[\r\n]+$//;
    }
    $t ||= $hint || '';
    $t = lc($t);
    # Normalize common variants
    if ($t =~ /^(ufs|ffs)$/) { return 'ufs'; }
    if ($t =~ /^(msdos|msdosfs|fat|fat32)$/) { return 'msdosfs'; }
    if ($t =~ /^(ext2|ext2fs)$/) { return 'ext2fs'; }
    if ($t =~ /^zfs$/) { return 'zfs'; }
    if ($t =~ /^swap/) { return 'swap'; }
    return $t || undef;
}

sub get_check_filesystem_command {
    my ($disk, $slice, $part) = @_;
    my $device = $part ? $part->{'device'} : $slice->{'device'};
    my $hint   = $part ? $part->{'type'}   : $slice->{'type'};
    my $fstype = detect_filesystem_type($device, $hint);
    # Map to specific fsck tools when available; else use fsck -t
    if ($fstype && $fstype eq 'ufs') {
        return has_command('fsck_ufs') ? "fsck_ufs -y $device" : "fsck -t ufs -y $device";
    }
    if ($fstype && $fstype eq 'msdosfs') {
        return has_command('fsck_msdosfs') ? "fsck_msdosfs -y $device" : "fsck -t msdosfs -y $device";
    }
    if ($fstype && $fstype eq 'ext2fs') {
        return has_command('fsck_ext2fs') ? "fsck_ext2fs -y $device" : "fsck -t ext2fs -y $device";
    }
    if ($fstype && $fstype eq 'zfs') {
        return "zpool status 2>&1"; # caller should avoid fsck for ZFS, but safe fallback
    }
    if ($fstype && $fstype eq 'swap') {
        return "echo 'swap device - fsck not applicable'";
    }
    # Generic fallback
    return "fsck -y $device";
}

sub show_filesystem_buttons {
    my ($hiddens, $st, $object) = @_;
    # Use preferred device path (label-based if available)
    my $preferred_dev = preferred_device_path($object->{'device'});
    print ui_buttons_row("newfs_form.cgi", $text{'part_newfs'}, $text{'part_newfsdesc'}, $hiddens);
    # Do not offer fsck for swap or ZFS devices
    my $zmap = get_all_zfs_info();
    my $is_swap = (@$st && $st->[1] eq 'swap') || ($object->{'type'} && $object->{'type'} =~ /freebsd-swap|^82$/i);
    my $is_zfs  = $zmap->{$object->{'device'}} ? 1 : 0;
    if ((!@$st || !$is_swap) && !$is_zfs) {
        print ui_buttons_row("fsck.cgi", $text{'part_fsck'}, $text{'part_fsckdesc'}, $hiddens);
    }
    if (!@$st) {
        if ($object->{'type'} eq 'swap' or $object->{'type'} eq '82' or $object->{'type'} eq 'freebsd-swap') {
            print ui_buttons_row("../mount/edit_mount.cgi", $text{'part_newmount2'}, $text{'part_mountmsg2'},
                ui_hidden("newdev", $preferred_dev) . ui_hidden("type", "swap"));
        }
        else {
            print ui_buttons_row("../mount/edit_mount.cgi", $text{'part_newmount'}, $text{'part_mountmsg'},
                ui_hidden("newdev", $preferred_dev) . ui_hidden("type", "ufs") . ui_textbox("newdir", undef, 20));
        }
    }
}

#---------------------------------------------------------------------
# ZFS and GEOM related functions are largely unchanged.
sub get_all_zfs_info {
    # Wrapper built from the structured ZFS devices cache
    my ($pools, $devices) = build_zfs_devices_cache();
    my %zfs_info;
    foreach my $id (keys %$devices) {
        next unless $id =~ /^\/dev\//; # focus on canonical /dev/* keys
        my $dev = $devices->{$id};
        my $suffix = ($dev->{'vdev_type'} && $dev->{'vdev_type'} eq 'log') ? '(log)' : '(data)';
        $zfs_info{$id} = $dev->{'pool'} . ' ' . $suffix;
    }
    return \%zfs_info;
}

sub get_type_description {
    my ($type) = @_;
    my %type_map = (
        'freebsd'         => 'FreeBSD',
        'freebsd-ufs'     => 'FreeBSD UFS',
        'freebsd-swap'    => 'FreeBSD Swap',
        'freebsd-vinum'   => 'FreeBSD Vinum',
        'freebsd-zfs'     => 'FreeBSD ZFS',
        'freebsd-boot'    => 'FreeBSD Boot',
        'efi'             => 'EFI System',
        'bios-boot'       => 'BIOS Boot',
        'ms-basic-data'   => 'Microsoft Basic Data',
        'ms-reserved'     => 'Microsoft Reserved',
        'ms-recovery'     => 'Microsoft Recovery',
        'apple-ufs'       => 'Apple UFS',
        'apple-hfs'       => 'Apple HFS',
        'apple-boot'      => 'Apple Boot',
        'apple-raid'      => 'Apple RAID',
        'apple-label'     => 'Apple Label',
        'linux-data'      => 'Linux Data',
        'linux-swap'      => 'Linux Swap',
        'linux-lvm'       => 'Linux LVM',
        'linux-raid'      => 'Linux RAID',
    );
    return $type_map{$type} || $type;
}

sub get_disk_structure {
    my ($device) = @_;
    my $result = { 'entries' => [], 'partitions' => {} };
    my $cmd = "gpart show -l $device 2>&1";
    my $out = backquote_command($cmd);
    if ($out =~ /=>\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+\(([^)]+)\)/) {
        my $start_block = $1;                     # starting block
        my $size_blocks = $2;                      # number of blocks
        $result->{'total_blocks'} = $start_block + $size_blocks;  # last addressable block + 1
        $result->{'device_name'}  = $3;            # device name (e.g., da0)
        $result->{'scheme'}       = $4;            # GPT/MBR
        $result->{'size_human'}   = $5;            # human size from header
    }
    foreach my $line (split(/\n/, $out)) {
        # Free space rows
        if ($line =~ /^\s+(\d+)\s+(\d+)\s+-\s+free\s+-\s+\(([^)]+)\)/) {
            push @{$result->{'entries'}}, {
                'start'      => $1,
                'size'       => $2,
                'size_human' => $3,
                'type'       => 'free'
            };
            next;
        }
        # Partition rows from `gpart show -l` have: start size index label [flags] (size_human)
        # Some systems include optional tokens like "[active]" after the label. Accept them.
        if ($line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)(?:\s+\[[^\]]+\])?\s+\(([^)]+)\)/) {
            push @{$result->{'entries'}}, {
                'start'      => $1,
                'size'       => $2,
                'index'      => $3,
                'label'      => $4,
                'size_human' => $5,
                'type'       => 'partition'
            };
        }
    }
    # Merge additional info from 'gpart list' directly, keyed by Name -> index
    my $list_out = backquote_command("gpart list $device 2>&1");
    my (%parts, $current_idx);
    foreach my $line (split(/\n/, $list_out)) {
        if ($line =~ /^\s*(?:\d+\.\s*)?Name:\s*(\S+)/i) {
            my $name = $1;              # e.g., da0p2 or da0s2
            if ($name =~ /[ps](\d+)$/) {
                $current_idx = int($1);
                $parts{$current_idx} ||= { name => $name };
            } else {
                undef $current_idx;     # not a partition provider line
            }
        }
        elsif (defined $current_idx && $line =~ /^\s*Index:\s*(\d+)/i) {
            # Optional cross-check; ignore value and trust Name-derived index
            next;
        }
        elsif (defined $current_idx && $line =~ /^\s*label:\s*(\S+)/i) {
            $parts{$current_idx}->{'label'} = $1;
        }
        elsif (defined $current_idx && $line =~ /^\s*type:\s*(\S+)/i) {
            $parts{$current_idx}->{'type'} = $1;
        }
        elsif (defined $current_idx && $line =~ /^\s*rawtype:\s*(\S+)/i) {
            $parts{$current_idx}->{'rawtype'} = $1;
        }
        elsif (defined $current_idx && $line =~ /^\s*length:\s*(\d+)/i) {
            $parts{$current_idx}->{'length'} = $1;
        }
        elsif (defined $current_idx && $line =~ /^\s*offset:\s*(\d+)/i) {
            $parts{$current_idx}->{'offset'} = $1;
        }
        elsif ($line =~ /Sectorsize:\s*(\d+)/i) {
            $result->{'sectorsize'} = int($1);
        }
        elsif ($line =~ /Mediasize:\s*(\d+)/i) {
            $result->{'mediasize'} = int($1);
        }
    }
    $result->{'partitions'} = \%parts;
    foreach my $entry (@{$result->{'entries'}}) {
        next unless ($entry->{'type'} eq 'partition' && $entry->{'index'});
        my $idx = $entry->{'index'};
        if ($parts{$idx}) {
            # Prefer label from gpart list if present and meaningful
            if ($parts{$idx}->{'label'} && $parts{$idx}->{'label'} ne '(null)') {
                $entry->{'label'} = $parts{$idx}->{'label'};
            }
            # Attach resolved type (rawtype/type) for downstream consumers
            $entry->{'part_type'} = $parts{$idx}->{'type'} || $parts{$idx}->{'rawtype'} || $entry->{'part_type'};
            # Also store rawtype for downstream consumers
            $entry->{'rawtype'} = $parts{$idx}->{'rawtype'} if ($parts{$idx}->{'rawtype'});
        }
    }
    return $result;
}



sub get_disk_sectorsize {
    my ($device) = @_;
    # Normalize device for diskinfo (expects provider name like da0)
    my $dev = $device; $dev =~ s{^/dev/}{};
    # Prefer verbose output which explicitly lists sectorsize
    my $outv = backquote_command("diskinfo -v $dev 2>/dev/null");
    if ($outv =~ /sectorsize:\s*(\d+)/i) {
        return int($1);
    }
    # Fallback to non-verbose; actual format: name sectorsize mediasize ...
    my $out = backquote_command("diskinfo $dev 2>/dev/null");
    if ($out =~ /^\S+\s+(\d+)\s+\d+/) {
        return int($1); # second field is sectorsize
    }
    # Last resort: ask gpart list for sectorsize
    my $base = $dev;
    my $ds = get_disk_structure($base);
    if ($ds && $ds->{'sectorsize'}) { return int($ds->{'sectorsize'}); }
    return undef;
}

# Derive the base disk device (e.g., /dev/da0 from /dev/da0p2)
sub base_disk_device {
    my ($device) = @_;
    return undef unless $device;
    my $d = $device;
    $d =~ s{^/dev/}{};
    $d =~ s{(p|s)\d+.*$}{}; # strip partition/slice suffix
    return "/dev/$d";
}

# Compute bytes from a block count for a given device
sub bytes_from_blocks {
    my ($device, $blocks) = @_;
    return undef unless defined $blocks;
    my $base = base_disk_device($device) || $device;
    my $ss = get_disk_sectorsize($base) || 512;
    return $blocks * $ss;
}

# Safe wrapper for nice_size that ensures bytes input
# Accepts either raw bytes or (device, blocks) pair
sub safe_nice_size {
    my ($arg1, $arg2) = @_;
    my $bytes;
    if (defined $arg2) {
        # Called as (device, blocks)
        $bytes = bytes_from_blocks($arg1, $arg2);
    } else {
        # Called as (bytes)
        $bytes = $arg1;
    }
    return '-' unless defined $bytes && $bytes >= 0;
    my $s = nice_size($bytes);
    # Normalize IEC suffixes to SI-style labels if present
    $s =~ s/\bKiB\b/KB/g;
    $s =~ s/\bMiB\b/MB/g;
    $s =~ s/\bGiB\b/GB/g;
    $s =~ s/\bTiB\b/TB/g;
    $s =~ s/\bPiB\b/PB/g;
    $s =~ s/\bEiB\b/EB/g;
    return $s;
}

sub build_zfs_devices_cache {
    my %pools;
    my %devices;
    my $cmd = "zpool status 2>&1";
    my $out = backquote_command($cmd);
    my ($current_pool, $in_config, $current_vdev_type, $current_vdev_group, 
        $is_mirrored, $is_raidz, $raidz_level, $is_single, $is_striped, $vdev_count);
    $current_vdev_type = 'data';
    foreach my $line (split(/\n/, $out)) {
        if ($line =~ /^\s*pool:\s+(\S+)/) {
            $current_pool = $1;
            $pools{$current_pool} = 1;
            $in_config = 0;
            $current_vdev_type = 'data';
        }
        elsif ($line =~ /^\s*config:/) {
            $in_config = 1;
            $current_vdev_group = undef;
            $is_mirrored = 0;
            $is_raidz = 0;
            $raidz_level = 0;
            $is_single = 0;
            $is_striped = 0;
            $vdev_count = 0;
        }
        elsif ($in_config and $line =~ /^\s+logs/) {
            $current_vdev_type = 'log';
            $current_vdev_group = undef;
        }
        elsif ($in_config and $line =~ /^\s+cache/) {
            $current_vdev_type = 'cache';
            $current_vdev_group = undef;
        }
        elsif ($in_config and $line =~ /^\s+spares/) {
            $current_vdev_type = 'spare';
            $current_vdev_group = undef;
        }
        elsif ($in_config and $line =~ /^\s+mirror-(\d+)/) {
            $current_vdev_group = "mirror-$1";
            $is_mirrored = 1;
            $is_raidz = 0;
            $is_single = 0;
            $is_striped = 0;
            $vdev_count = 0;
        }
        elsif ($in_config and $line =~ /^\s+raidz(\d+)?-(\d+)/) {
            $current_vdev_group = "raidz" . ($1 || "1") . "-$2";
            $is_mirrored = 0;
            $is_raidz = 1;
            $raidz_level = $1 || 1;
            $is_single = 0;
            $is_striped = 0;
            $vdev_count = 0;
        }
        elsif ($in_config and $line =~ /^\s+(\S+)\s+(\S+)/) {
            my $device = $1;
            my $state  = $2;
            next if ($device eq $current_pool or $device =~ /^mirror-/ or $device =~ /^raidz\d*-/);
            if ($current_vdev_group) { $vdev_count++; }
            else { $is_single = 1; }
            my $device_id = $device;
            $device_id = $1 if ($device =~ /^gpt\/(.*)/);
            $devices{$device} = {
                'pool'        => $current_pool,
                'vdev_type'   => $current_vdev_type,
                'is_mirrored' => $is_mirrored,
                'is_raidz'    => $is_raidz,
                'raidz_level' => $raidz_level,
                'is_single'   => $is_single,
                'is_striped'  => $is_striped,
                'vdev_group'  => $current_vdev_group,
                'vdev_count'  => $vdev_count
            };
            $devices{"gpt/$device"} = $devices{$device} if ($device !~ /^gpt\//);
            $devices{"/dev/$device"} = $devices{$device};
            if ($device !~ /^gpt\//) {
                $devices{"/dev/gpt/$device"} = $devices{$device};
            }
            $devices{lc($device)} = $devices{$device};
            if ($device !~ /^gpt\//) {
                $devices{"gpt/" . lc($device)} = $devices{$device};
                $devices{"/dev/gpt/" . lc($device)} = $devices{$device};
            }
        }
    }
    return (\%pools, \%devices);
}

sub get_format_type {
    my ($part) = @_;
    if ($part->{'type'} =~ /^freebsd-/) {
        return get_type_description($part->{'type'});
    }
    return get_type_description($part->{'type'}) || $part->{'type'};
}

# Build possible ids for a partition given base device, scheme and metadata
sub _possible_partition_ids {
    my ($base_device, $scheme, $part_num, $part_name, $part_label) = @_;
    my @ids;
    if (defined $base_device && defined $part_num && length($base_device)) {
        my $sep = ($scheme && $scheme eq 'GPT') ? 'p' : 's';
        my $device_path = "/dev/$base_device" . $sep . $part_num;
        push(@ids, $device_path);
        (my $short = $device_path) =~ s/^\/dev\///;
        push(@ids, $short);
    }
    if ($part_name && $part_name ne '-') {
        push(@ids, $part_name, "/dev/$part_name");
    }
    if (defined $part_label && $part_label ne '-' && $part_label ne '(null)') {
        push(@ids, $part_label, "gpt/$part_label", "/dev/gpt/$part_label",
              lc($part_label), "gpt/".lc($part_label), "/dev/gpt/".lc($part_label));
        if ($part_label =~ /^(sLOG\w+)$/) {
            push(@ids, $1, "gpt/$1", "/dev/gpt/$1");
        }
    }
    return @ids;
}

# Given ids, find if present in ZFS devices cache
sub _find_in_zfs {
    my ($zfs_devices, @ids) = @_;
    foreach my $id (@ids) {
        my $nid = lc($id);
        if ($zfs_devices->{$nid}) {
            return $zfs_devices->{$nid};
        }
    }
    return undef;
}

# Classify a partition row: returns (format, usage, role)
sub classify_partition_row {
    my (%args) = @_;
    my $ids = [ _possible_partition_ids(@args{qw/base_device scheme part_num part_name part_label/}) ];
    my $zdev = _find_in_zfs($args{'zfs_devices'}, @$ids);

    # Derive type description, avoid label-as-type
    my $type_desc = $args{'entry_part_type'};
    if (!defined $type_desc || $type_desc eq '-' || $type_desc eq 'unknown') {
        # leave undef
    }
    # Avoid clearing real types (like 'efi' or 'freebsd-boot') when label text matches by case.
    # Only drop if the "type" clearly looks like a provider/label path that mirrors the label.
    if (defined $type_desc && defined $args{'part_label'}) {
        my $pl = $args{'part_label'};
        if ($type_desc =~ m{^(?:/dev/)?gpt(?:id)?/\Q$pl\E$}i) {
            undef $type_desc;
        }
    }

    my ($format, $usage, $role) = ('-', $text{'part_nouse'}, '-');
    # Explicit boot detection based on GPT GUIDs and MBR hex codes or human-readable type
    my $raw = lc($args{'entry_rawtype'} || '');
    my $t   = lc($type_desc || '');
    my %boot_guid = map { $_ => 1 } qw(
        c12a7328-f81f-11d2-ba4b-00a0c93ec93b   # EFI System
        21686148-6449-6e6f-744e-656564454649   # BIOS Boot (GRUB BIOS)
        83bd6b9d-7f41-11dc-be0b-001560b84f0f   # FreeBSD Boot
        49f48d5a-b10e-11dc-b99b-0019d1879648   # NetBSD boot
        824cc7a0-36a8-11e3-890a-952519ad3f61   # OpenBSD boot
        426f6f74-0000-11aa-aa11-00306543ecac   # Apple Boot
    );
    my %boot_mbr = map { $_ => 1 } qw( 0xef 0xa0 0xa5 0xa6 0xa9 0xab );
    my $is_boot_type = ($t =~ /\b(efi|bios-?boot|freebsd-boot|netbsd-boot|openbsd-boot|apple-boot)\b/);
    my $is_boot_raw  = ($raw && ($boot_guid{$raw} || $boot_mbr{$raw}));
    if ($is_boot_type || $is_boot_raw) {
        my $fmt = ($t =~ /efi/ || $raw eq 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' || lc($raw) eq '0xef') ? get_type_description('efi') : get_type_description('freebsd-boot');
        # Access text properly - %text is in main namespace when this is called from CGI
        my $boot_txt = $text{'disk_boot'};
        my $role_txt = $text{'disk_boot_role'};
        return ($fmt, $boot_txt, $role_txt);
    }
    # Heuristic fallback only if no explicit identifiers are present
    if ((!$args{'entry_part_type'} || $args{'entry_part_type'} eq '-' || $args{'entry_part_type'} eq 'unknown') && ($args{'part_num'}||'') eq '1') {
        my $sb = $args{'size_blocks'} || 0;
        if ($sb > 0) {
            my $base = base_disk_device('/dev/' . ($args{'base_device'}||''));
            my $ss = get_disk_sectorsize($base) || 512;
            my $bytes = $sb * $ss;
            if ($bytes <= 2*1024*1024) { # <= 2MiB
                return (get_type_description('freebsd-boot'), $text{'disk_boot'}, $text{'disk_boot_role'});
            }
        } elsif ($args{'size_human'} && $args{'size_human'} =~ /^(?:512k|1m|1\.0m)$/i) {
            return (get_type_description('freebsd-boot'), $text{'disk_boot'}, $text{'disk_boot_role'});
        }
    }
    if ($zdev) {
        $format = 'FreeBSD ZFS';
        my $inzfs_txt   = $text{'disk_inzfs'};
        my $z_mirror    = $text{'disk_zfs_mirror'};
        my $z_stripe    = $text{'disk_zfs_stripe'};
        my $z_single    = $text{'disk_zfs_single'};
        my $z_data      = $text{'disk_zfs_data'};
        my $z_log       = $text{'disk_zfs_log'};
        my $z_cache     = $text{'disk_zfs_cache'};
        my $z_spare     = $text{'disk_zfs_spare'};
        $usage  = $inzfs_txt . ' ' . $zdev->{'pool'};
        my $vt  = $zdev->{'vdev_type'};
        my $cnt = $zdev->{'vdev_count'} || 0;
        if ($vt eq 'log') { $role = $z_log; }
        elsif ($vt eq 'cache') { $role = $z_cache; }
        elsif ($vt eq 'spare') { $role = $z_spare; }
        elsif ($zdev->{'is_mirrored'}) {
            $role = $z_mirror;
            $role .= " ($cnt in group)" if $cnt;
        }
        elsif ($zdev->{'is_raidz'}) {
            my $lvl = $zdev->{'raidz_level'} || 1;
            $role = 'RAID-Z' . $lvl;
            $role .= " ($cnt in group)" if $cnt;
        }
        elsif ($zdev->{'is_striped'}) {
            $role = $z_stripe;
            $role .= " ($cnt in group)" if $cnt;
        }
        elsif ($zdev->{'is_single'}) { $role = $z_single; }
        else { $role = $z_data; }
        return ($format, $usage, $role);
    }

    # Not in ZFS: infer by type_desc, rawtype and size heuristic (this shouldn't be reached for boot, but keep as fallback)
    if (defined $type_desc && $type_desc =~ /(?:freebsd|linux)-swap/i) {
        $format = 'Swap';
        $usage = $text{'disk_swap'} ;
        $role = $text{'disk_swap_role'} ;
    }
    elsif (defined $type_desc && $type_desc =~ /linux-lvm/i) { $format = 'Linux LVM'; }
    elsif (defined $type_desc && $type_desc =~ /linux-raid/i) { $format = 'Linux RAID'; }
    # Recognize common FAT/NTFS identifiers on both GPT and MBR
    elsif (defined $type_desc && $type_desc =~ /ntfs/i) { $format = 'NTFS'; }
    elsif (defined $type_desc && $type_desc =~ /fat32/i) { $format = 'FAT32'; }
    elsif (defined $type_desc && $type_desc =~ /fat|msdos/i) { $format = 'FAT'; }
    elsif (defined $type_desc && $type_desc =~ /ms-basic/i) { $format = 'FAT/NTFS'; }
    elsif ($raw ne '' && $raw =~ /^\d+$/) {
        # MBR raw type codes: 7=NTFS, 6/11/12/14 = FAT variants
        my $code = int($raw);
        if ($code == 7) { $format = 'NTFS'; }
        elsif ($code == 11 || $code == 12) { $format = 'FAT32'; }
        elsif ($code == 6 || $code == 14) { $format = 'FAT'; }
    }
    elsif (defined $type_desc && $type_desc =~ /linux/i) { $format = 'Linux'; }
    elsif (defined $type_desc && $type_desc =~ /apple-ufs/i) { $format = 'Apple UFS'; }
    elsif (defined $type_desc && $type_desc =~ /apple-hfs/i) { $format = 'HFS+'; }
    elsif (defined $type_desc && $type_desc =~ /apple-raid/i) { $format = 'Apple RAID'; }
    elsif (defined $type_desc && $type_desc =~ /freebsd-ufs/i) { $format = 'FreeBSD UFS'; }
    elsif (defined $type_desc && $type_desc =~ /freebsd-zfs/i) { $format = 'FreeBSD ZFS'; }
    else {
        if (defined $args{'part_label'} && $args{'part_label'} =~ /^swap\d*$/i) {
            $format = 'Swap';
            $usage = $text{'disk_swap'} ;
            $role = $text{'disk_swap_role'} ;
        }
    }
    return ($format, $usage, $role);
}

# list_partition_types()
# Returns a list suitable for ui_select: [ [ value, label ], ... ]
# Adapts to whether the system uses gpart (GPT) or legacy disklabel.
sub list_partition_types {
    my ($scheme) = @_;
    if (is_using_gpart()) {
        # BSD-on-MBR inner label (used when creating sub-partitions inside an MBR slice)
        if (defined $scheme && $scheme =~ /BSD/i) {
            return (
                [ 'freebsd-ufs',  get_type_description('freebsd-ufs') ],
                [ 'freebsd-zfs',  get_type_description('freebsd-zfs') ],
                [ 'freebsd-swap', get_type_description('freebsd-swap') ],
                [ 'freebsd-vinum',get_type_description('freebsd-vinum') ],
            );
        }
        # If outer scheme is not GPT (e.g. MBR), present MBR partition types for top-level slices
        if (defined $scheme && $scheme !~ /GPT/i) {
            my @mbr_types = (
                [ 'freebsd',    get_type_description('freebsd') ],
                [ 'fat32lba',   'FAT32 (LBA)' ],
                [ 'fat32',      'FAT32' ],
                [ 'fat16',      'FAT16' ],
                [ 'ntfs',       'NTFS' ],
                [ 'linux',      'Linux' ],
                [ 'linux-swap', get_type_description('linux-swap') ],
                [ 'efi',        get_type_description('efi') ],
            );
            return @mbr_types;
        }
        # Default GPT types
        my @gpt_types = (
            [ 'efi',            get_type_description('efi')            ],
            [ 'bios-boot',      get_type_description('bios-boot')      ],
            [ 'freebsd-boot',   get_type_description('freebsd-boot')   ],
            [ 'freebsd-zfs',    get_type_description('freebsd-zfs')    ],
            [ 'freebsd-ufs',    get_type_description('freebsd-ufs')    ],
            [ 'freebsd-swap',   get_type_description('freebsd-swap')   ],
            [ 'freebsd-vinum',  get_type_description('freebsd-vinum')  ],
            [ 'ms-basic-data',  get_type_description('ms-basic-data')  ],
            [ 'ms-reserved',    get_type_description('ms-reserved')    ],
            [ 'ms-recovery',    get_type_description('ms-recovery')    ],
            [ 'linux-data',     get_type_description('linux-data')     ],
            [ 'linux-swap',     get_type_description('linux-swap')     ],
            [ 'linux-lvm',      get_type_description('linux-lvm')      ],
            [ 'linux-raid',     get_type_description('linux-raid')     ],
            [ 'apple-boot',     get_type_description('apple-boot')     ],
            [ 'apple-hfs',      get_type_description('apple-hfs')      ],
            [ 'apple-ufs',      get_type_description('apple-ufs')      ],
            [ 'apple-raid',     get_type_description('apple-raid')     ],
            [ 'apple-label',    get_type_description('apple-label')    ],
        );
        return @gpt_types;
    } else {
        # Legacy BSD disklabel types
        my @label_types = (
            [ '4.2BSD', 'FreeBSD UFS' ],
            [ 'swap',   'Swap'         ],
            [ 'unused', 'Unused'       ],
            [ 'vinum',  'FreeBSD Vinum'],
        );
        return @label_types;
    }
}
 

sub get_partition_role {
    my ($part) = @_;
    if (is_boot_partition($part)) { return $text{'part_boot'}; }
    my $zfs_info = get_all_zfs_info();
    if ($zfs_info->{$part->{'device'}} and $zfs_info->{$part->{'device'}} =~ /\(log\)$/) {
        return $text{'part_zfslog'};
    }
    if ($zfs_info->{$part->{'device'}}) {
        return $text{'part_zfsdata'};
    }
    my @mounts = mount::list_mounted();
    foreach my $m (@mounts) {
        if ($m->[0] eq $part->{'device'}) {
            return text('part_mounted', $m->[1]);
        }
    }
    return $text{'part_unused'};
}

sub get_detailed_disk_info {
    my ($device) = @_;
    my $info = {};
    (my $dev_name = $device) =~ s/^\/dev\///;
    my $out = backquote_command("geom disk list $dev_name 2>/dev/null");
    return undef if ($?);
    foreach my $line (split(/\n/, $out)) {
        if ($line =~ /^\s+Mediasize:\s+(\d+)\s+\(([^)]+)\)/) {
            $info->{'mediasize_bytes'} = $1;
            $info->{'mediasize'} = $2;
        }
        elsif ($line =~ /^\s+Sectorsize:\s+(\d+)/) {
            $info->{'sectorsize'} = $1;
        }
        elsif ($line =~ /^\s+Stripesize:\s+(\d+)/) {
            $info->{'stripesize'} = $1;
        }
        elsif ($line =~ /^\s+Stripeoffset:\s+(\d+)/) {
            $info->{'stripeoffset'} = $1;
        }
        elsif ($line =~ /^\s+Mode:\s+(.*)/) {
            $info->{'mode'} = $1;
        }
        elsif ($line =~ /^\s+rotationrate:\s+(\d+)/) {
            $info->{'rotationrate'} = $1;
        }
        elsif ($line =~ /^\s+ident:\s+(.*)/) {
            $info->{'ident'} = $1;
        }
        elsif ($line =~ /^\s+lunid:\s+(.*)/) {
            $info->{'lunid'} = $1;
        }
        elsif ($line =~ /^\s+descr:\s+(.*)/) {
            $info->{'descr'} = $1;
        }
    }
    return $info;
}

sub initialize_slice {
    my ($disk, $slice) = @_;
    # If the outer disk is GPT, we are not creating inner BSD labels
    if (is_using_gpart()) {
        my $base = $disk->{'device'}; $base =~ s{^/dev/}{};
        my $ds = get_disk_structure($base);
        if ($ds && $ds->{'scheme'} && $ds->{'scheme'} =~ /GPT/i) {
            return undef;
        }
    }
    # For MBR: initialize BSD disklabel on the slice only if not already present
    my $prov = slice_name($slice);
    my $show = backquote_command("gpart show $prov 2>&1");
    return undef if ($show =~ /\bBSD\b/);
    my $cmd = "gpart create -s BSD $prov 2>&1";
    my $out = `$cmd`;
    if ($? != 0) {
        return "Failed to initialize slice: $out";
    }
    return undef;
}

# ---------------------------------------------------------------------
# partition_select(name, value)
# Provide a selector for partitions/slices for external modules (e.g., mount)
# Returns an HTML <select> element populated with available devices.
sub partition_select {
    my ($name, $value) = @_;
    my @opts;
    my @disks = list_disks_partitions();
    foreach my $d (@disks) {
        foreach my $s (@{ $d->{'slices'} || [] }) {
            my $stype = get_type_description($s->{'type'}) || $s->{'type'};
            my $ssize_b = bytes_from_blocks($s->{'device'}, $s->{'blocks'});
            my $ssize = defined $ssize_b ? nice_size($ssize_b) : undef;
            my $slabel = $s->{'device'} . (defined $ssize ? " ($stype, $ssize)" : " ($stype)");
            push @opts, [ $s->{'device'}, $slabel ];
            foreach my $p (@{ $s->{'parts'} || [] }) {
                my $ptype = get_type_description($p->{'type'}) || $p->{'type'};
                my $psz_b   = bytes_from_blocks($p->{'device'}, $p->{'blocks'});
                my $psz   = defined $psz_b ? nice_size($psz_b) : undef;
                my $plabel = $p->{'device'} . (defined $psz ? " ($ptype, $psz)" : " ($ptype)");
                push @opts, [ $p->{'device'}, $plabel ];
            }
        }
    }
    # Sort options by device name for consistency
    @opts = sort { $a->[0] cmp $b->[0] } @opts;
    $value ||= ($opts[0] ? $opts[0]->[0] : undef);
    return ui_select($name, $value, \@opts, 1, 0, 0, 0);
}

# Return a short human-readable description for a given device
# Example: "FreeBSD ZFS, 39G"
sub partition_description {
    my ($device) = @_;
    return undef unless $device;
    my ($ptype, $blocks);
    my @disks = list_disks_partitions();
    foreach my $d (@disks) {
        foreach my $s (@{ $d->{'slices'} || [] }) {
            if ($s->{'device'} && $s->{'device'} eq $device) {
                $ptype  = get_type_description($s->{'type'}) || $s->{'type'};
                $blocks = $s->{'blocks'}; last;
            }
            foreach my $p (@{ $s->{'parts'} || [] }) {
                if ($p->{'device'} && $p->{'device'} eq $device) {
                    $ptype  = get_type_description($p->{'type'}) || $p->{'type'};
                    $blocks = $p->{'blocks'}; last;
                }
            }
        }
    }
    return undef unless defined $ptype;
    my $bytes = bytes_from_blocks($device, $blocks);
    my $sz    = defined $bytes ? nice_size($bytes) : '-';
    return "$ptype, $sz";
}

1;