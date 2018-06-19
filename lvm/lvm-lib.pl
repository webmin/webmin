# lvm-lib.pl
# Common functions for managing VGs, PVs and LVs

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount");
if (&foreign_check("raid")) {
	&foreign_require("raid");
	$has_raid++;
	}
&foreign_require("fdisk");

$lvm_proc = "/proc/lvm";
$lvm_tab = "/etc/lvmtab";

# list_physical_volumes(vg)
# Returns a list of all physical volumes for some volume group
sub list_physical_volumes
{
local @rv;
if (-d $lvm_proc) {
	# Get list from /proc/lvm
	opendir(DIR, "$lvm_proc/VGs/$_[0]/PVs");
	foreach $f (readdir(DIR)) {
		next if ($f eq '.' || $f eq '..');
		local $pv = { 'name' => $f,
			      'vg' => $_[0] };
		local %p = &parse_colon_file("$lvm_proc/VGs/$_[0]/PVs/$f");
		$pv->{'device'} = $p{'name'};
		$pv->{'number'} = $p{'number'};
		$pv->{'size'} = $p{'size'}/2;
		$pv->{'status'} = $p{'status'};
		$pv->{'number'} = $p{'number'};
		$pv->{'pe_size'} = $p{'PE size'};
		$pv->{'pe_total'} = $p{'PE total'};
		$pv->{'pe_alloc'} = $p{'PE allocated'};
		$pv->{'alloc'} = $p{'allocatable'} == 2 ? 'y' : 'n';
		push(@rv, $pv);
		}
	closedir(DIR);
	}
else {
	# Use pvdisplay command
	local $pv;
	local $_;
	open(DISPLAY, "pvdisplay 2>/dev/null |");
	while(<DISPLAY>) {
		s/\r|\n//g;
		if (/PV\s+Name\s+(.*)/i) {
			$pv = { 'name' => $1,
				'device' => $1,
				'number' => scalar(@rv) };
			$pv->{'name'} =~ s/^\/dev\///;
			push(@rv, $pv);
			}
		elsif (/VG\s+Name\s+(.*)/i) {
			$pv->{'vg'} = $1;
			$pv->{'vg'} =~ s/\s+\(.*\)//;
			}
		elsif (/PV\s+Size\s+<?(\S+)\s+(\S+)/i) {
			$pv->{'size'} = &mult_units($1, $2);
			}
		elsif (/PE\s+Size\s+\(\S+\)\s+(\S+)/i) {
			$pv->{'pe_size'} = $1;
			}
		elsif (/PE\s+Size\s+(\S+)\s+(\S+)/i) {
			$pv->{'pe_size'} = &mult_units($1, $2);
			}
		elsif (/Total\s+PE\s+(\S+)/i) {
			$pv->{'pe_total'} = $1;
			}
		elsif (/Allocated\s+PE\s+(\S+)/i) {
			$pv->{'pe_alloc'} = $1;
			}
		elsif (/Allocatable\s+(\S+)/i) {
			$pv->{'alloc'} = lc($1) eq 'yes' ? 'y' : 'n';
			}
		}
	close(DISPLAY);
	@rv = grep { $_->{'vg'} eq $_[0] } @rv;
	@rv = grep { $_->{'name'} ne 'unknown device' } @rv;
	}
return @rv;
}

# get_physical_volume_usage(&lv)
# Returns a list of LVs and blocks used on this physical volume
sub get_physical_volume_usage
{
local @rv;
open(DISPLAY, "pvdisplay -m ".quotemeta($_[0]->{'device'})." 2>/dev/null |");
local $lastlen;
while(<DISPLAY>) {
	if (/Physical\s+extent\s+(\d+)\s+to\s+(\d+)/) {
		$lastlen = $2 - $1 + 1;
		}
	elsif (/Logical\s+volume\s+\/dev\/(\S+)\/(\S+)/) {
		push(@rv, [ $2, $lastlen ]);
		}
	}
close(DISPLAY);
return @rv;
}

# create_physical_volume(&pv, [force])
# Add a new physical volume to a volume group
sub create_physical_volume
{
local $cmd = "pvcreate -y ".($_[1] ? "-ff " : "-f ");
$cmd .= quotemeta($_[0]->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $out if ($?);
$cmd = "vgextend ".quotemeta($_[0]->{'vg'})." ".quotemeta($_[0]->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# change_physical_volume(&pv)
# Change the allocation flag for a physical volume
sub change_physical_volume
{
local $cmd = "pvchange -x ".quotemeta($_[0]->{'alloc'}).
	     " ".quotemeta($_[0]->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# delete_physical_volume(&pv)
# Remove a physical volume from a volume group
sub delete_physical_volume
{
if ($_[0]->{'pe_alloc'}) {
	local $cmd;
	if (&get_lvm_version() >= 2) {
		$cmd = "yes | pvmove ".quotemeta($_[0]->{'device'});
		}
	else {
		$cmd = "pvmove -f ".quotemeta($_[0]->{'device'});
		}
	local $out = &backquote_logged("$cmd 2>&1");
	return $out if ($? && $out !~ /\-\-\s+f/);
	}
local $cmd = "vgreduce ".quotemeta($_[0]->{'vg'})." ".
	     quotemeta($_[0]->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# resize_physical_volume(&pv)
# Set the size of a physical volume to match the underlying device
sub resize_physical_volume
{
local $cmd = "pvresize ".quotemeta($_[0]->{'device'});
local $out = &backquote_logged("$cmd 2>&1");
return $? ? $out : undef;
}

# list_volume_groups()
# Returns a list of all volume groups
sub list_volume_groups
{
local (@rv, $f);
if (-d $lvm_proc) {
	# Can scan /proc/lvm
	opendir(DIR, "$lvm_proc/VGs");
	foreach $f (readdir(DIR)) {
		next if ($f eq '.' || $f eq '..');
		local $vg = { 'name' => $f };
		local %g = &parse_colon_file("$lvm_proc/VGs/$f/group");
		$vg->{'number'} = $g{'number'};
		$vg->{'size'} = $g{'size'};
		$vg->{'pe_size'} = $g{'PE size'};
		$vg->{'pe_total'} = $g{'PE total'};
		$vg->{'pe_alloc'} = $g{'PE allocated'};
		push(@rv, $vg);
		}
	closedir(DIR);
	}
else {
	# Parse output of vgdisplay
	local $vg;
	open(DISPLAY, "vgdisplay 2>/dev/null |");
	while(<DISPLAY>) {
		s/\r|\n//g;
		if (/VG\s+Name\s+(.*)/i) {
			$vg = { 'name' => $1 };
			push(@rv, $vg);
			}
		elsif (/VG\s+Size\s+<?(\S+)\s+(\S+)/i) {
			$vg->{'size'} = &mult_units($1, $2);
			}
		elsif (/PE\s+Size\s+(\S+)\s+(\S+)/i) {
			$vg->{'pe_size'} = &mult_units($1, $2);
			}
		elsif (/Total\s+PE\s+(\d+)/i) {
			$vg->{'pe_total'} = $1;
			}
		elsif (/Alloc\s+PE\s+\/\s+Size\s+(\d+)/i) {
			$vg->{'pe_alloc'} = $1;
			}
		}
	close(DISPLAY);
	}
return @rv;
}

sub mult_units
{
local ($n, $u) = @_;
return $n*(uc($u) eq "KB" || uc($u) eq "KIB" ? 1 :
	   uc($u) eq "MB" || uc($u) eq "MIB" ? 1024 :
	   uc($u) eq "GB" || uc($u) eq "GIB" ? 1024*1024 :
	   uc($u) eq "TB" || uc($u) eq "TIB" ? 1024*1024*1024 :
	   uc($u) eq "PB" || uc($u) eq "PIB" ? 1024*1024*1024 : 1);
}

# delete_volume_group(&vg)
sub delete_volume_group
{
local $cmd = "vgchange -a n ".quotemeta($_[0]->{'name'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $out if ($?);
$cmd = "vgremove ".quotemeta($_[0]->{'name'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# create_volume_group(&vg, device)
sub create_volume_group
{
&system_logged("vgscan >/dev/null 2>&1 </dev/null");
local $cmd = "pvcreate -f -y ".quotemeta($_[1]);
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $out if ($?);
$cmd = "vgcreate";
$cmd .= " -s ".quotemeta($_[0]->{'pe_size'})."k" if ($_[0]->{'pe_size'});
$cmd .= " ".quotemeta($_[0]->{'name'})." ".quotemeta($_[1]);
$out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# rename_volume_group(&vg, name)
sub rename_volume_group
{
local $cmd = "vgrename ".quotemeta($_[0]->{'name'})." ".quotemeta($_[1]);
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $out if ($?);
$cmd = "vgchange -a n ".quotemeta($_[1]);
$out = &backquote_logged("$cmd 2>&1 </dev/null");
return $out if ($?);
$cmd = "vgchange -a y ".quotemeta($_[1]);
$out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}


# list_logical_volumes(vg)
sub list_logical_volumes
{
local @rv;
if (-d $lvm_proc) {
	# Get LVs from /proc/lvm
	opendir(DIR, "$lvm_proc/VGs/$_[0]/LVs");
	foreach $f (readdir(DIR)) {
		next if ($f eq '.' || $f eq '..');
		local $lv = { 'name' => $f,
			      'vg' => $_[0] };
		local %p = &parse_colon_file("$lvm_proc/VGs/$_[0]/LVs/$f");
		$lv->{'device'} = $p{'name'};
		$lv->{'number'} = $p{'number'};
		$lv->{'size'} = $p{'size'}/2;
		$lv->{'perm'} = $p{'access'} == 3 ? 'rw' : 'r';
		$lv->{'alloc'} = $p{'allocation'} == 2 ? 'y' : 'n';
		$lv->{'has_snap'} = $p{'access'} == 11;
		$lv->{'is_snap'} = $p{'access'} == 5;
		$lv->{'stripes'} = $p{'stripes'};
		push(@rv, $lv);

		# For snapshots, use the lvdisplay command to get usage
		if ($lv->{'is_snap'}) {
			local $out = &backquote_command(
				"lvdisplay ".quotemeta($lv->{'device'}).
				" 2>/dev/null");
			if ($out =~/Allocated\s+to\s+snapshot\s+([0-9\.]+)%/i) {
				$lv->{'snapusage'} = $1;
				}
			}
		}
	closedir(DIR);
	}
else {
	# Use the lvdisplay command
	local $lv;
	local $_;
	local ($vg) = grep { $_->{'name'} eq $_[0] } &list_volume_groups();
	open(DISPLAY, "lvdisplay -m 2>/dev/null |");
	while(<DISPLAY>) {
		s/\r|\n//g;
		if (/LV\s+(Name|Path)\s+(.*\/(\S+))/i) {
			$lv = { 'name' => $3,
				'device' => $2,
				'number' => scalar(@rv) };
			push(@rv, $lv);
			}
		elsif (/LV\s+Name\s+([^\/ ]+)/) {
			# Ignore this, as we got the name from LV Path line.
			# UNLESS it doesn't match the current LV, in which
			# case it is the start of a new thinpool LV.
			if (!@rv || $rv[$#rv]->{'name'} ne $1) {
				$lv = { 'name' => $1,
					'device' => $1,
					'thin' => $1,
					'number' => scalar(@rv) };
				push(@rv, $lv);
				}
			}
		elsif (/VG\s+Name\s+(.*)/) {
			$lv->{'vg'} = $1;
			}
		elsif (/LV\s+Size\s+<?(\S+)\s+(\S+)/i) {
			$lv->{'size'} = &mult_units($1, $2);
			}
		elsif (/Current\s+LE\s+(\d+)/ && $vg) {
			$lv->{'size'} = $1 * $vg->{'pe_size'};
			}
		elsif (/COW-table\s+LE\s+(\d+)/ && $vg) {
			$lv->{'cow_size'} = $1 * $vg->{'pe_size'};
			}
		elsif (/LV\s+Write\s+Access\s+(\S+)/i) {
			$lv->{'perm'} = $1 eq 'read/write' ? 'rw' : 'r';
			}
		elsif (/Allocation\s+(.*)/i) {
			$lv->{'alloc'} = $1 eq 'contiguous' ? 'y' : 'n';
			}
		elsif (/LV\s+snapshot\s+status\s+(.*)/i) {
			if ($1 =~ /source/) {
				$lv->{'has_snap'} = 1;
				}
			else {
				$lv->{'is_snap'} = 1;
				}
			if (/destination\s+for\s+\/dev\/[^\/]+\/(\S+)/) {
				$lv->{'snap_of'} = $1;
				}
			if (/active\s+destination/i) {
				$lv->{'snap_active'} = 1;
				}
			elsif (/INACTIVE\s+destination/i) {
				$lv->{'snap_active'} = 0;
				}
			}
		elsif (/LV\s+Thin\s+origin\s+name\s+(\S+)/) {
			# Snapshot in a thin pool
			$lv->{'is_snap'} = 1;
			$lv->{'snap_of'} = $1;
			}
		elsif (/Read ahead sectors\s+(\d+|auto)/) {
                        $lv->{'readahead'} = $1;
                        }
		elsif (/Stripes\s+(\d+)/) {
			$lv->{'stripes'} = $1;
			}
		elsif (/Stripe\s+size\s+(\S+)\s+(\S+)/) {
			$lv->{'stripesize'} = &mult_units($1, $2);
			}
		elsif (/Allocated\s+to\s+snapshot\s+([0-9\.]+)%/i) {
			$lv->{'snapusage'} = $1;
			}
		elsif (/LV\s+Pool\s+name\s+(\S+)/) {
			$lv->{'thin_in'} = $1;
			}
		elsif (/Allocated\s+pool\s+data\s+(\S+)%/) {
			$lv->{'thin_percent'} = $1;
			$lv->{'thin_used'} = $1 / 100.0 * $lv->{'size'};
			}
		}
	close(DISPLAY);
	@rv = grep { $_->{'vg'} eq $_[0] } @rv;
	}
return @rv;
}

# get_logical_volume_usage(&lv)
# Returns a list of PVs and blocks used by this logical volume. Each is an
# array ref of : device physical-blocks reads writes
sub get_logical_volume_usage
{
local ($lv) = @_;
local @rv;
if (&get_lvm_version() >= 2) {
	# LVdisplay has new format in version 2
	open(DISPLAY, "lvdisplay -m ".quotemeta($lv->{'device'})." 2>/dev/null |");
	while(<DISPLAY>) {
		if (/\s+Physical\s+volume\s+\/dev\/(\S+)/) {
			push(@rv, [ $1, undef ]);
			}
		elsif (/\s+Physical\s+extents\s+(\d+)\s+to\s+(\d+)/ && @rv) {
			$rv[$#rv]->[1] = $2-$1+1;
			}
		}
	close(DISPLAY);
	}
else {
	# Old version 1 format
	open(DISPLAY, "lvdisplay -v ".quotemeta($lv->{'device'})." 2>/dev/null |");
	local $started;
	while(<DISPLAY>) {
		if (/^\s*PV\s+Name/i) {
			$started = 1;
			}
		elsif ($started && /^\s*\/dev\/(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
			push(@rv, [ $1, $2, $3, $4 ]);
			}
		elsif ($started) {
			last;
			}
		}
	close(DISPLAY);
	}
return @rv;
}

# create_logical_volume(&lv)
# Creates a new LV, and returns undef on success or an error message on failure
sub create_logical_volume
{
local ($lv) = @_;
local $cmd = "lvcreate -n".quotemeta($lv->{'name'})." ";
local $suffix;
if ($lv->{'size_of'} eq 'VG' || $lv->{'size_of'} eq 'FREE' ||
    $lv->{'size_of'} eq 'ORIGIN') {
	$cmd .= "-l ".quotemeta("$lv->{'size'}%$lv->{'size_of'}");
	}
elsif ($lv->{'size_of'}) {
	$cmd .= "-l $lv->{'size'}%PVS";
	$suffix = " ".quotemeta("/dev/".$lv->{'size_of'});
	}
elsif ($lv->{'thin_in'} && $lv->{'is_snap'}) {
	# For a snapshot inside a thin pool, no size is needed
	}
else {
	$cmd .= ($lv->{'thin_in'} ? "-V" : "-L").$lv->{'size'}."k";
	}
if ($lv->{'is_snap'}) {
	$cmd .= " -s ".quotemeta("/dev/$lv->{'vg'}/$lv->{'snapof'}");
	}
else {
	$cmd .= " -p ".quotemeta($lv->{'perm'});
	if (!$lv->{'thin_in'}) {
		$cmd .= " -C ".quotemeta($lv->{'alloc'});
		}
	$cmd .= " -r ".quotemeta($lv->{'readahead'})
		if ($lv->{'readahead'} && $lv->{'readahead'} ne "auto");
	$cmd .= " -i ".quotemeta($lv->{'stripe'})
		if ($lv->{'stripe'});
	$cmd .= " -I ".quotemeta($lv->{'stripesize'})
		if ($lv->{'stripesize'} && $lv->{'stripe'});
	if ($lv->{'thin_in'}) {
		$cmd .= " --thinpool ".quotemeta($lv->{'vg'})."/".
				       quotemeta($lv->{'thin_in'});
		}
	else {
		$cmd .= " ".quotemeta($lv->{'vg'});
		}
	}
$cmd .= $suffix;
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# delete_logical_volume(&lv)
# Deletes an existing LV, and returns undef on success or an error message
sub delete_logical_volume
{
local ($lv) = @_;

# First delete any /dev/mapper entries for the LV
my $mapper = $lv->{'vg'}."-".$lv->{'lv'};
my $dashvg = $lv->{'vg'};
$dashvg =~ s/\-/\-\-/g;
my $dashmapper = $dashvg."-".$lv->{'lv'};
opendir(MAPPER, "/dev/mapper");
my @files = readdir(MAPPER);
closedir(MAPPER);
my @delmaps;
foreach my $f (@files) {
	if ($f =~ /^\Q$mapper\Ep?\d+$/ ||
	    $f =~ /^\Q$dashmapper\Ep?\d+$/) {
		push(@delmaps, $f);
		}
	}
foreach my $f (@files) {
	if ($f eq $mapper || $f eq $dashmapper) {
		push(@delmaps, $f);
		}
	}
foreach my $f (@delmaps) {
	&system_logged("dmsetup remove /dev/mapper/$f >/dev/null 2>&1");
	}

# Finally remove the LV
local $cmd = "lvremove -f ".quotemeta($lv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# resize_logical_volume(&lv, size)
# Grows or shrinks a regular LV to the new size in KB
sub resize_logical_volume
{
local ($lv, $size) = @_;
local $cmd = $size > $lv->{'size'} ? "lvextend" : "lvreduce -f";
$cmd .= " -L".quotemeta($size)."k";
$cmd .= " ".quotemeta($lv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# resize_snapshot_volume(&lv, size)
# Grows or shrinks a snapshot LV to the new size in KB
sub resize_snapshot_volume
{
local ($lv, $size) = @_;
local $cmd = $size > $lv->{'cow_size'} ? "lvextend" : "lvreduce -f";
$cmd .= " -L".quotemeta($size)."k";
$cmd .= " ".quotemeta($lv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# change_logical_volume(&lv, [&old-lv])
# Changes various parameters of an LV< like the permissions and readahead
sub change_logical_volume
{
local ($lv, $oldlv) = @_;
local $cmd = "lvchange ";
$cmd .= " -p ".quotemeta($lv->{'perm'})
	if (!$oldlv || $lv->{'perm'} ne $oldlv->{'perm'});
$cmd .= " -r ".quotemeta($lv->{'readahead'})
	if (!$oldlv || $lv->{'readahead'} ne $oldlv->{'readahead'});
$cmd .= " -C ".quotemeta($lv->{'alloc'})
	if (!$oldlv || $lv->{'alloc'} ne $oldlv->{'alloc'});
$cmd .= " ".quotemeta($lv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# rename_logical_volume(&lv, name)
# Renames an existing LV
sub rename_logical_volume
{
local ($lv, $name) = @_;
local $cmd = "lvrename ".quotemeta($lv->{'device'})." ".
	     quotemeta("/dev/$lv->{'vg'}/$name");
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# rollback_snapshot(&lv)
# Returns the underlying LV to the state in the given snapshot
sub rollback_snapshot
{
local ($lv) = @_;
local $cmd = "lvconvert --merge ".quotemeta($lv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# can_resize_filesystem(type)
# 0 = no, 1 = enlarge only, 2 = enlarge or shrink
sub can_resize_filesystem
{
local ($type) = @_;
if ($type =~ /^ext\d+$/) {
	if (&has_command("e2fsadm")) {
		return 2;	# Can extend and reduce
		}
	elsif (&has_command("resize2fs")) {
		# Only new versions can reduce a FS
		local $out = &backquote_command("resize2fs 2>&1");
		return $out =~ /resize2fs\s+([0-9\.]+)/i && $1 >= 1.4 ? 2 : 1;
		}
	else {
		return 0;
		}
	}
elsif ($type eq "xfs") {
	return &has_command("xfs_growfs") ? 1 : 0;
	}
elsif ($type eq "reiserfs") {
	return &has_command("resize_reiserfs") ? 2 : 0;
	}
elsif ($type eq "jfs") {
	return 1;
	}
else {
	return 0;
	}
}

# can_resize_lv_stat(dir, type, mounted)
# Returns 1 if some LV can be enlarged, 2 if enlarged or shrunk, or 0
# if neither, based on the details provided by device_status
sub can_resize_lv_stat
{
local ($dir, $type, $mounted) = @_;
if (!$type) {
	# No FS known, assume can resize safely
	return 2;
	}
else {
	my $can = &can_resize_filesystem($type);
	if ($can && $mounted) {
		# If currently mounted, check if resizing is possible
		if ($type =~ /^ext[3-9]$/ || $type eq "xfs" ||
		    $type eq "reiserfs" || $type eq "jfs") {
			# ext*, xfs, jfs and reiserfs can be resized up
			$can = 1;
			}
		else {
			# Nothing else can
			$can = 0;
			}
		}
	return $can;
	}
}

# resize_filesystem(&lv, type, size)
sub resize_filesystem
{
if ($_[1] =~ /^ext\d+$/) {
	&foreign_require("proc");
	if (&has_command("e2fsadm")) {
		# The e2fsadm command can re-size an LVM and filesystem together
		local $cmd = "e2fsadm -v -L ".quotemeta($_[2])."k ".
			     quotemeta($_[0]->{'device'});
		local ($fh, $fpid) = &proc::pty_process_exec($cmd);
		print $fh "yes\n";
		local $out;
		while(<$fh>) {
			$out .= $_;
			}
		close($fh);
		waitpid($fpid, 0);
		&additional_log("exec", undef, $cmd);
		return $? ? $out : undef;
		}
	else {
		if ($_[2] > $_[0]->{'size'}) {
			# Need to enlarge LV first, then filesystem
			local $err = &resize_logical_volume($_[0], $_[2]);
			return $err if ($err);

			local $cmd = "resize2fs -f ".
				     quotemeta($_[0]->{'device'});
			local $out = &backquote_logged("$cmd 2>&1");
			return $? ? $out : undef;
			}
		else {
			# Need to shrink filesystem first, then LV
			local $cmd = "resize2fs -f ".
				     quotemeta($_[0]->{'device'})." ".
				     quotemeta($_[2])."k";
			local $out = &backquote_logged("$cmd 2>&1");
			return $out if ($?);

			local $err = &resize_logical_volume($_[0], $_[2]);
			return $err;
			}
		}
	}
elsif ($_[1] eq "xfs") {
	# Resize the logical volume first
	local $err = &resize_logical_volume($_[0], $_[2]);
	return $err if ($err);

	# Resize the filesystem .. which must be mounted!
	local @stat = &device_status($_[0]->{'device'});
	local ($m, $mount);
	foreach $m (&mount::list_mounts()) {
		if ($m->[1] eq $_[0]->{'device'}) {
			$mount = $m;
			}
		}
	if (!$stat[2]) {
		$mount || return "Mount not found";
		&mount::mount_dir(@$mount);
		}
	local $cmd = "xfs_growfs ".quotemeta($stat[0] || $mount->[0]);
	local $out = &backquote_logged("$cmd 2>&1");
	local $q = $?;
	if (!$stat[2]) {
		&mount::unmount_dir(@$mount);
		}
	return $q ? $out : undef;
	}
elsif ($_[1] eq "reiserfs") {
	if ($_[2] > $_[0]->{'size'}) {
		# Enlarge the logical volume first
		local $err = &resize_logical_volume($_[0], $_[2]);
		return $err if ($err);

		# Now enlarge the reiserfs filesystem
		local $cmd = "resize_reiserfs ".quotemeta($_[0]->{'device'});
		local $out = &backquote_logged("$cmd 2>&1");
		return $? ? $out : undef;
		}
	else {
		# Try to shrink the filesystem
		local $cmd = "yes | resize_reiserfs -s ".
			     quotemeta($_[2])."K ".quotemeta($_[0]->{'device'});
		local $out = &backquote_logged("$cmd 2>&1");
		return $out if ($?);

		# Now shrink the logical volume
		local $err = &resize_logical_volume($_[0], $_[2]);
		return $err ? $err : undef;
		}
	}
elsif ($_[1] eq "jfs") {
	# Enlarge the logical volume first
	local $err = &resize_logical_volume($_[0], $_[2]);
	return $err if ($err);

	# Now enlarge the jfs filesystem with a remount - must be mounted first
	local @stat = &device_status($_[0]->{'device'});
	local ($m, $mount);
	foreach $m (&mount::list_mounts()) {
		if ($m->[1] eq $_[0]->{'device'}) {
			$mount = $m;
			}
		}
	if (!$stat[2]) {
		$mount || return "Mount not found";
		&mount::mount_dir(@$mount);
		}
	local $ropts = $mount->[3];
	$ropts = $ropts eq "-" ? "resize,remount" : "$ropts,resize,remount";
	local $err = &mount::mount_dir($mount->[0], $mount->[1],
				       $mount->[2], $ropts);
	if (!$stat[2]) {
		&mount::unmount_dir(@$mount);
		}
	return $err ? $err : undef;
	}
else {
	return "???";
	}
}


# parse_colon_file(file)
sub parse_colon_file
{
local %rv;
open(FILE, $_[0]);
while(<FILE>) {
	if (/^([^:]+):\s*(.*)/) {
		$rv{$1} = $2;
		}
	}
close(FILE);
return %rv;
}

# device_status(device)
# Returns an array of  directory, type, mounted
sub device_status
{
local ($dev) = @_;
return ( ) if ($dev !~ /^\//);
local @st = &fdisk::device_status($dev);
return @st if (@st);
if (&foreign_check("server-manager")) {
	# Look for Cloudmin systems using the disk, hosted on this system
	if (!@server_manager_systems) {
		&foreign_require("server-manager");
		@server_manager_systems =
			grep { my $p = &server_manager::get_parent_server($_);
			       $p && $p->{'id'} eq '0' }
			     &server_manager::list_managed_servers();
		}
	foreach my $s (@server_manager_systems) {
		if ($s->{$s->{'manager'}.'_filesystem'} eq $_[0]) {
			return ( $s->{'host'}, 'cloudmin', 
			         $s->{'status'} ne 'down' );
			}
		my $ffunc = "type_".$s->{'manager'}."_list_disk_devices";
		if (&foreign_defined("server-manager", $ffunc)) {
			my @disks = &foreign_call("server-manager", $ffunc, $s);
			if (&indexof($_[0], @disks) >= 0) {
				return ( $s->{'host'}, 'cloudmin', 
					 $s->{'status'} ne 'down' );
				}
			}
		}
	}
return ();
}

# device_message(stat)
# Returns a text string about the status of an LV
sub device_message
{
my $msg;
if ($_[1] eq 'cloudmin') {
	# Used by Cloudmin system
	$msg = $_[2] ? 'lv_mountcm' : 'lv_umountcm';
	return &text($msg, "<tt>$_[0]</tt>");
	}
else {
	# Used by filesystem or RAID or iSCSI
	$msg = $_[2] ? 'lv_mount' : 'lv_umount';
	$msg .= 'vm' if ($_[1] eq 'swap');
	$msg .= 'raid' if ($_[1] eq 'raid');
	$msg .= 'iscsi' if ($_[1] eq 'iscsi');
	return &text($msg, "<tt>$_[0]</tt>", "<tt>$_[1]</tt>");
	}
}

# list_lvmtab()
sub list_lvmtab
{
local @rv;
open(TAB, $lvm_tab);
local $/ = "\0";
while(<TAB>) {
	chop;
	push(@rv, $_) if ($_);
	}
close(TAB);
return @rv;
}

# device_input()
# Returns a selector for a free device
sub device_input
{
local (%used, $vg, $pv, $d, $p);

# Find partitions that are part of an LVM
foreach $vg (&list_volume_groups()) {
	foreach $pv (&list_physical_volumes($vg->{'name'})) {
		$used{$pv->{'device'}}++;
		}
	}

# Show available partitions
local @opts;
foreach $d (&fdisk::list_disks_partitions()) {
	foreach $p (@{$d->{'parts'}}) {
		next if ($used{$p->{'device'}} || $p->{'extended'});
		local @ds = &device_status($p->{'device'});
		next if (@ds);
		if ($p->{'type'} eq '83' || $p->{'type'} eq 'ext2') {
			local $label = &fdisk::get_label($p->{'device'});
			next if ($used{"LABEL=$label"});
			}
		local $tag = &fdisk::tag_name($p->{'type'});
		push(@opts, [ $p->{'device'},
			$p->{'desc'}.
			($tag ? " ($tag)" : "").
			($d->{'cylsize'} ? " (".&nice_size($d->{'cylsize'}*($p->{'end'} - $p->{'start'} + 1)).")" :
			" ($p->{'blocks'} $text{'blocks'})") ]);
		}
	}

# Show available RAID devices
local $conf = &raid::get_raidtab();
foreach $c (@$conf) {
	next if ($used{$c->{'value'}});
	local @ds = &device_status($c->{'value'});
	next if (@ds);
	push(@opts, [ $c->{'value'}, &text('pv_raid', $c->{'value'} =~ /md(\d+)$/ ? "$1" : $c->{'value'}) ]);
	}

push(@opts, [ '', $text{'pv_other'} ]);
return &ui_select("device", $opts[0]->[0], \@opts)." ".
       &ui_textbox("other", undef, 30)." ".&file_chooser_button("other").
       "<br>\n<b>$text{'pv_warn'}</b>";
}

# get_lvm_version()
# Returns the lvm version number and optionally output from the vgdisplay
# command used to get it.
sub get_lvm_version
{
local $out = `vgdisplay --version 2>&1`;
local $ver = $out =~ /\s+([0-9\.]+)/ ? $1 : undef;
return wantarray ? ( $ver, $out ) : $ver;
}

# nice_round(number)
# Round some number to TB, GB, MB or kB, depending on size
sub nice_round
{
local ($bytes) = @_;
my $units;
if ($bytes >= 10*1024*1024*1024*1024) {
        $units = 1024*1024*1024*1024;
        }
elsif ($bytes >= 10*1024*1024*1024) {
        $units = 1024*1024*1024;
        }
elsif ($bytes >= 10*1024*1024) {
        $units = 1024*1024;
        }
elsif ($bytes >= 10*1024) {
        $units = 1024;
        }
else {
	$units = 1;
	}
return int($bytes / $units) * $units;
}

# move_logical_volume(&lv, from, to, [print])
# Moves blocks on an LV from one PV to another. Returns an error message on
# failure, or undef on success
sub move_logical_volume
{
local ($lv, $from, $to, $print) = @_;
local $cmd = "pvmove -n $lv->{'name'} /dev/$from /dev/$to";
if ($print) {
	open(OUT, "$cmd 2>&1 </dev/null |");
	my $old = select(OUT);
	$| = 1;
	select($old);
	while(<OUT>) {
		print &html_escape($_);
		}
	my $ex = close(OUT);
	return $? ? "Failed" : undef;
	}
else {
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	return $? ? $out : undef;
	}
}

# supports_snapshot_rollback()
# Only newer kernels safely support this (2.6.35 and above)
sub supports_snapshot_rollback
{
my $out = &backquote_command("uname -r 2>/dev/null </dev/null");
return $out =~ /^(\d+)\./ && $1 >= 3 ||
       $out =~ /^(\d+)\.(\d+)/ && $1 == 2 && $2 >= 7 ||
       $out =~ /^(\d+)\.(\d+)\.(\d+)/ && $1 == 2 && $2 == 6 && $3 >= 35;
}

# create_thin_pool(&data-lv, &metadata-lv)
# Convert two LVs into a thin pool
sub create_thin_pool
{
local ($datalv, $metadatalv) = @_;
local $cmd = "lvconvert -y --type thin-pool --poolmetadata ".
	     quotemeta($metadatalv->{'device'})." ".
	     quotemeta($datalv->{'device'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

1;

