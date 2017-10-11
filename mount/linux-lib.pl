# linux-lib.pl
# Mount table functions for linux

if (!$no_check_support) {
	my %support;
	my $fsfile = &read_file_contents("/proc/filesystems");
	foreach my $l (split(/\r?\n/, $fsfile)) {
		my @w = split(/\s+/, $l);
		my $fs = pop(@w);
		$support{$fs} = 1;
		}
	if (&has_command("amd")) {
		local $amd = &read_amd_conf();
		$amd_support = $amd =~ /\[\s*global\s*\]/i ? 2 : 1;
		}
	$autofs_support = &has_command("automount");
	if (&has_command("mount.cifs")) {
		$cifs_support = 4;
		}
	if (&has_command("mount.smbfs")) {
		$smbfs_support = &backquote_command("mount.smbfs -v 2>&1", 1) =~ /username=/i ? 4 : 3;
		$smbfs_fs = "smbfs";
		}
	elsif (&has_command("mount.smb")) {
		$smbfs_support = &backquote_command("mount.smb -v 2>&1", 1) =~ /username=/i ? 4 : 3;
		$smbfs_fs = "smb";
		}
	elsif (&has_command("smbmount")) {
		$smbfs_support = &backquote_command("smbmount -v 2>&1", 1) =~ /Version\s+2/i ? 2 : 1;
		$smbfs_fs = "smbfs";
		}
	$swaps_support = -r "/proc/swaps";
	$tmpfs_support = 1;
	$ext3_support = 1;
	$no_mount_check = 1;
	$bind_support = 1;
	if ($support{'ext4'}) {
		$ext4_support = 1;
		}
	if ($support{'xfs'} || &has_command("mkfs.xfs")) {
		$xfs_support = 1;
		}
	if ($support{'jfs'} || &has_command("mkfs.jfs")) {
		$jfs_support = 1;
		}
	if ($support{'btrfs'} || &has_command("mkfs.btrfs")) {
		$btrfs_support = 1;
		}
	}

# We always need to check this, to fix up LABEL= mounts
if (&has_command("e2label")) {
	$has_e2label = 1;
	}
if (&has_command("xfs_db")) {
	$has_xfs_db = 1;
	}
if (&has_command("vol_id")) {
	$has_volid = 1;
	}
if (&has_command("reiserfstune")) {
	$has_reiserfstune = 1;
	}
$uuid_directory = "/dev/disk/by-uuid";

# Return information about a filesystem, in the form:
#  directory, device, type, options, fsck_order, mount_at_boot
# If a field is unused or ignored, a - appears instead of the value.
# Swap-filesystems (devices or files mounted for VM) have a type of 'swap',
# and 'swap' in the directory field
sub list_mounts
{
return @list_mounts_cache if (@list_mounts_cache);
local(@rv, @p, @o, $_, $i, $j);
$i = 0;

# Get /etc/fstab mounts
open(FSTAB, $config{fstab_file});
while(<FSTAB>) {
	local(@o, $at_boot);
	chop; s/#.*$//g;
	if (!/\S/ || /\signore\s/) { next; }
	if (/\t+[^\t]+\t+[^\t+]\t+/) {
		# Contains at least 3 tabs .. assume tab separation
		@p = split(/\t+/, $_);
		}
	else {
		@p = split(/\s+/, $_);
		}
	if ($p[2] eq "proc") { $p[0] = "proc"; }
	elsif ($p[2] eq "auto") { $p[2] = "*"; }
	elsif ($p[2] eq "swap") { $p[1] = "swap"; }
	elsif ($p[2] eq $smbfs_fs || $p[2] eq "cifs") {
		$p[0] =~ s/\\040/ /g;
		$p[0] =~ s/\//\\/g;
		}
	$p[1] = &simplify_path($p[1]);
	$rv[$i] = [ $p[1], $p[0], $p[2] ];
	$rv[$i]->[5] = "yes";
	@o = split(/,/ , $p[3] eq "defaults" ? "" : $p[3]);
	if (($j = &indexof("noauto", @o)) >= 0) {
		# filesytem is not mounted at boot
		splice(@o, $j, 1);
		$rv[$i]->[5] = "no";
		}
	if (($j = &indexof("bind", @o)) >= 0) {
		# Special bind option, which indicates a loopback filesystem
		splice(@o, $j, 1);
		$rv[$i]->[2] = "bind";
		}
	$rv[$i]->[3] = (@o ? join(',' , @o) : "-");
	$rv[$i]->[4] = (@p >= 5 ? $p[5] : 0);
	$i++;
	}
close(FSTAB);

if ($amd_support == 1) {
	# Get old automounter configuration, as used by redhat
	local $amd = &read_amd_conf();
	if ($amd =~ /MOUNTPTS='(.*)'/) {
		@p = split(/\s+/, $1);
		for($j=0; $j<@p; $j+=2) {
			$rv[$i++] = [ $p[$j], $p[$j+1], "auto",
				      "-", 0, "yes" ];
			}
		}
	}
elsif ($amd_support == 2) {
	# Guess what? There's now a *new* amd config file format, introduced
	# in redhat 6.1 and caldera 2.3
	local @amd = &parse_amd_conf();
	local @sp = split(/:/, $amd[0]->{'opts'}->{'search_path'});
	local ($am, $sp);
	foreach $am (@amd) {
		local $mn = $am->{'opts'}->{'map_name'};
		if ($mn !~ /^\//) {
			foreach $sp (@sp) {
				if (-r "$sp/$mn") {
					$mn = "$sp/$mn";
					last;
					}
				}
			}
		$rv[$i++] = [ $am->{'dir'}, $mn,
			      "auto", $am->{'opts'}, 0, "yes" ]
			if ($am->{'dir'} ne 'global');
		}
	}

# Get kernel automounter configuration
if ($autofs_support) {
	open(AUTO, $config{'autofs_file'});
	while(<AUTO>) {
		chop;
		s/#.*$//g;
		if (/^\s*(\S+)\s+(\S+)\s*(.*)$/) {
			$rv[$i++] = [ $1, $2, "autofs",
				      ($3 ? &autofs_options($3) : "-"),
				      0, "yes" ];
			}
		}
	close(AUTO);
	}

@list_mounts_cache = @rv;
return @rv;
}


# create_mount(directory, device, type, options, fsck_order, mount_at_boot)
# Add a new entry to the fstab file, old or new automounter file
sub create_mount
{
local(@mlist, @amd, $_); local($opts);

if ($_[2] eq "auto") {
	if ($amd_support == 1) {
		# Adding an old automounter mount
		local $amd = &read_amd_conf();
		local $m = "$_[0] $_[1]";
		if ($amd =~ /MOUNTPTS=''/) {
			$amd =~ s/MOUNTPTS=''/MOUNTPTS='$m'/;
			}
		else {
			$amd =~ s/MOUNTPTS='(.*)'/MOUNTPTS='$1 $m'/;
			}
		&write_amd_conf($amd);
		}
	elsif ($amd_support == 2) {
		# Adding a new automounter mount
		local @amfs = split(/\s+/, $config{'auto_file'});
		&open_tempfile(AMD, ">>$amfs[0]");
		&print_tempfile(AMD, "\n");
		&print_tempfile(AMD, "[ $_[0] ]\n");
		&print_tempfile(AMD, "map_name = $_[1]\n");
		&close_tempfile(AMD);
		}
	}
elsif ($_[2] eq "autofs") {
	# Adding a new automounter mount
	&open_tempfile(AUTO, ">> $config{'autofs_file'}");
	&print_tempfile(AUTO, "$_[0]  $_[1]");
	if ($_[3]) {
		&print_tempfile(AUTO, "  ",&autofs_args($_[3]));
		}
	&print_tempfile(AUTO, "\n");
	&close_tempfile(AUTO);
	}
else {
	# Adding a normal mount to the fstab file
	local $dev = $_[1];
	if ($_[2] eq $smbfs_fs || $_[2] eq "cifs") {
		$dev =~ s/\\/\//g;
		$dev =~ s/ /\\040/g;
		}
	&open_tempfile(FSTAB, ">> $config{fstab_file}");
	&print_tempfile(FSTAB, $dev."\t".$_[0]."\t".$_[2]);
	local @opts = $_[3] eq "-" ? ( ) : split(/,/, $_[3]);
	if ($_[5] eq "no") {
		push(@opts, "noauto");
		}
	else {
		@opts = grep { $_ !~ /^(auto|noauto)$/ } @opts;
		}
	if ($_[2] eq "bind") {
		push(@opts, "bind");
		}
	if (!@opts) { &print_tempfile(FSTAB, "\t"."defaults"); }
	else { &print_tempfile(FSTAB, "\t".join(",", @opts)); }
	&print_tempfile(FSTAB, "\t"."0"."\t");
	&print_tempfile(FSTAB, $_[4] eq "-" ? "0\n" : "$_[4]\n");
	&close_tempfile(FSTAB);
	}
undef(@list_mounts_cache);
}


# change_mount(num, directory, device, type, options, fsck_order, mount_at_boot)
# Change an existing permanent mount
sub change_mount
{
local($i, @fstab, $line, $opts, $j, @amd);
$i = 0;

# Update fstab file
open(FSTAB, $config{fstab_file});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, "> $config{fstab_file}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $line !~ /\signore\s/ && $i++ == $_[0]) {
		# Found the line to replace
		local $dev = $_[2];
		if ($_[3] eq $smbfs_fs || $_[3] eq "cifs") {
			$dev =~ s/\\/\//g;
			$dev =~ s/ /\\040/g;
			}
		&print_tempfile(FSTAB, $dev."\t".$_[1]."\t".$_[3]);
		local @opts = $_[4] eq "-" ? ( ) : split(/,/, $_[4]);
		if ($_[6] eq "no") {
			push(@opts, "noauto");
			}
		else {
			@opts = grep { $_ !~ /^(auto|noauto)$/ } @opts;
			}
		if ($_[3] eq "bind") {
			push(@opts, "bind");
			}
		if (!@opts) { &print_tempfile(FSTAB, "\t"."defaults"); }
		else { &print_tempfile(FSTAB, "\t".join(",", @opts)); }
		&print_tempfile(FSTAB, "\t"."0"."\t");
		&print_tempfile(FSTAB, $_[5] eq "-" ? "0\n" : "$_[5]\n");
		}
	else { &print_tempfile(FSTAB, $_,"\n"); }
	}
&close_tempfile(FSTAB);

if ($amd_support == 1) {
	# Update older amd configuration
	local $amd = &read_amd_conf();
	if ($amd =~ /MOUNTPTS='(.*)'/) {
		# found mount points line..
		local @mpts = split(/\s+/, $1);
		for($j=0; $j<@mpts; $j+=2) {
			if ($i++ == $_[0]) {
				$mpts[$j] = $_[1];
				$mpts[$j+1] = $_[2];
				}
			}
		local $mpts = join(" ", @mpts);
		$amd =~ s/MOUNTPTS='(.*)'/MOUNTPTS='$mpts'/;
		}
	&write_amd_conf($amd);
	}
elsif ($amd_support == 2) {
	# Update new amd configuration
	local @amd = &parse_amd_conf();
	foreach $am (@amd) {
		next if ($am->{'dir'} eq 'global');
		if ($i++ == $_[0]) {
			local $lref = &read_file_lines($am->{'file'});
			local @nl = ( "[ $_[1] ]" );
			local %opts = %{$am->{'opts'}};
			$opts{'map_name'} = $_[2];
			foreach $o (keys %opts) {
				push(@nl, "$o = $opts{$o}");
				}
			splice(@$lref, $am->{'line'},
			       $am->{'eline'} - $am->{'line'} + 1, @nl);
			&flush_file_lines();
			}
		}
	}

# Update autofs configuration
if ($autofs_support) {
	open(AUTO, $config{'autofs_file'});
	@auto = <AUTO>;
	close(AUTO);
	&open_tempfile(AUTO, "> $config{'autofs_file'}");
	foreach (@auto) {
		chop; ($line = $_) =~ s/#.*$//g;
		if ($line =~ /\S/ && $i++ == $_[0]) {
			&print_tempfile(AUTO, "$_[1]  $_[2]");
			if ($_[4]) {
				&print_tempfile(AUTO, "  ",&autofs_args($_[4]));
				}
			&print_tempfile(AUTO, "\n");
			}
		else {
			&print_tempfile(AUTO, $_,"\n");
			}
		}
	&close_tempfile(AUTO);
	}
undef(@list_mounts_cache);
}


# delete_mount(index)
# Delete an existing permanent mount
sub delete_mount
{
local($i, @fstab, $line, $opts, $j, @amd);
$i = 0;

# Update fstab file
open(FSTAB, $config{fstab_file});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, ">$config{fstab_file}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line !~ /\S/ || $line =~ /\signore\s/ || $i++ != $_[0]) {
		# Don't delete this line
		&print_tempfile(FSTAB, $_,"\n");
		}
	}
&close_tempfile(FSTAB);

if ($amd_support == 1) {
	# Update older amd configuration
	local $foundamd = 0;
	local $amd = &read_amd_conf();
	if ($amd =~ /MOUNTPTS='(.*)'/) {
		# found mount points line..
		local @mpts = split(/\s+/, $1);
		for($j=0; $j<@mpts; $j+=2) {
			if ($i++ == $_[0]) {
				splice(@mpts, $j, 2);
				$foundamd = 1;
				}
			}
		local $mpts = join(" ", @mpts);
		$amd =~ s/MOUNTPTS='(.*)'/MOUNTPTS='$mpts'/;
		}
	&write_amd_conf($amd) if ($foundamd);
	}
elsif ($amd_support == 2) {
	# Update new amd configuration
	local @amd = &parse_amd_conf();
	foreach $am (@amd) {
		next if ($am->{'dir'} eq 'global');
		if ($i++ == $_[0]) {
			local $lref = &read_file_lines($am->{'file'});
			splice(@$lref, $am->{'line'},
			       $am->{'eline'} - $am->{'line'} + 1);
			&flush_file_lines();
			}
		}
	}

# Update AMD file
if ($amd_support) {
	open(AMD, $config{auto_file});
	@amd = <AMD>;
	close(AMD);
	&open_tempfile(AMD, ">$config{auto_file}");
	foreach (@amd) {
		if (/MOUNTPTS='(.*)'/) {
			# found mount points line..
			@mpts = split(/\s+/, $1);
			for($j=0; $j<@mpts; $j+=2) {
				if ($i++ != $_[0]) {
					push(@nmpts, $mpts[$j]);
					push(@nmpts, $mpts[$j+1]);
					}
				}
			&print_tempfile(AMD, "MOUNTPTS='".join(' ', @nmpts)."'\n");
			}
		else { &print_tempfile(AMD, $_); }
		}
	&close_tempfile(AMD);
	}

# Update autofs file
if ($autofs_support) {
	open(AUTO, $config{'autofs_file'});
	@auto = <AUTO>;
	close(AUTO);
	&open_tempfile(AUTO, ">$config{'autofs_file'}");
	foreach (@auto) {
		chop; ($line = $_) =~ s/#.*$//g;
		if ($line !~ /\S/ || $i++ != $_[0]) {
			# keep this line
			&print_tempfile(AUTO, $_,"\n");
			}
		}
	&close_tempfile(AUTO);
	}
undef(@list_mounts_cache);
}


# list_mounted([no-label])
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
sub list_mounted
{
return @list_mounted_cache
	if (@list_mounted_cache && $list_mounted_cache_mode == $_[0]);
local(@rv, @p, @o, $mo, $_, %smbopts);
local @mounts = &list_mounts();

&read_smbopts();
open(MTAB, "/etc/mtab");
while(<MTAB>) {
	chop;
	s/#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	next if ($p[0] eq "rootfs");	# Bogus pseudo-fs
	$p[1] = &simplify_path($p[1]);
	if ($p[2] eq "auto" || $p[0] =~ /^\S+:\(pid\d+\)$/) {
		# Automounter map.. turn the map= option into the device
		@o = split(/,/ , $p[3]);
		($mo) = grep {/^map=/} (@o);
		$mo =~ /^map=(.*)$/; $p[0] = $1;
		$p[3] = join(',' , grep {!/^map=/} (@o));
		$p[2] = "auto";
		}
	elsif ($p[2] eq "autofs") {
		# Kernel automounter map.. use the pid to find the map
		$p[0] =~ /automount\(pid(\d+)\)/ || next;
		$out = &backquote_command("ps hwwww $1", 1);
		$out =~ /automount\s+(.*)\s*(\S+)\s+(file|program|yp)(,\S+)?\s+(\S+)/ || next;
		$p[0] = $5;
		$p[3] = $1 ? &autofs_options($1) : "-";
		}
	elsif ($p[2] eq $smbfs_fs || $p[2] eq "cifs") {
		# Change from //FOO/BAR to \\foo\bar
		$p[0] = &lowercase_share_path($p[0]);
		$p[3] = $smbopts{$p[1]};
		}
	elsif ($p[2] eq "proc") {
		# The source for proc mounts is always proc
		$p[0] = "proc";
		}
	if (!$_[0] && ($p[2] =~ /^ext\d+$/ && $has_e2label ||
	    	       $p[2] eq "xfs" && $has_xfs_db ||
		       $p[2] eq "reiserfs" && $has_reiserfstune)) {
		# Check for a label on this partition, and there is one
		# and this filesystem is in fstab with the label, change
		# the device.
		local $label;
		if ($p[2] eq "xfs") {
			local $out = &backquote_command("xfs_db -x -p xfs_admin -c label -r $p[0] 2>&1", 1);
			$label = $1 if ($out =~ /label\s*=\s*"(.*)"/ &&
					$1 ne '(null)');
			}
		elsif ($p[2] eq "reiserfs") {
			local $out = &backquote_command("reiserfstune $p[0] 2>&1");
			if ($out =~ /LABEL:\s*(\S+)/) {
				$label = $1;
				}
			}
		else {
			$label = &backquote_command("e2label $p[0] 2>&1", 1);
			chop($label);
			}
		if (!$?) {
			foreach $m (@mounts) {
				if ($m->[0] eq $p[1] &&
				    $m->[1] eq "LABEL=$label") {
					$p[0] = "LABEL=$label";
					last;
					}
				}
			}
		}

	# Check for a UUID on this partition, and if there is one
	# and the filesystem is in fstab with the label, change
	# the device.
	if (!$_[0]) {
		local $uuid = &device_to_uuid($p[0], \@mounts);
		if ($uuid) {
			$p[0] = "UUID=$uuid";
			}
		}

	# check fstab for a mount on the same dir which is a symlink
	# to the device
	local @st = stat($p[0]);
	foreach $m (@mounts) {
		if ($m->[0] eq $p[1]) {
			local @fst = stat($m->[1]);
			if ($fst[0] == $st[0] && $fst[1] == $st[1]) {
				# symlink to the same place!
				$p[0] = $m->[1];
				last;
				}
			}
		}

	if ($p[3] =~ s/,bind,// || $p[3] =~ s/^bind,// ||
	    $p[3] =~ s/,bind$// || $p[3] =~ s/^bind$//) {
		# Special bind option, which indicates a loopback filesystem
		$p[2] = "bind";
		}

	push(@rv, [ $p[1], $p[0], $p[2], $p[3] ]);
	}
close(MTAB);
open(SWAPS, "/proc/swaps");
while(<SWAPS>) {
	chop;
	if (/^(\/\S+)\s+/) {
		local $sf = $1;

		# check fstab for a mount on a device which is a symlink
		# to the path in /proc/swaps
		local @st = stat($sf);
		foreach $m (@mounts) {
			local @fst = stat($m->[1]);
			if ($m->[2] eq 'swap' && $fst[0] == $st[0] &&
			    $fst[1] == $st[1]) {
				$sf = $m->[1];
				last;
				}
			}

		# Convert to UUID format if used in fstab
		if (!$_[0]) {
			local $uuid = &device_to_uuid($sf, \@mounts);
			if ($uuid) {
				$sf = "UUID=$uuid";
				}
			}
		push(@rv, [ "swap", $sf, "swap", "-" ]);
		}
	}
close(SWAPS);
@list_mounted_cache = @rv;
$list_mounted_cache_mode = $_[0];
return @rv;
}

# device_to_uuid(device, [&mounts])
# Given a device name like /dev/sda1, return the UUID for it.
# If a list of mounts are given, only match if found in mount list.
sub device_to_uuid
{
local ($device, $mounts) = @_;
local $uuid;
if ($device =~ /^\Q$uuid_directory\E\/([^\/]+)$/) {
	# Device is already under the UUID directory, so ID can be found
	# immediately from the path
	$uuid = $1;
	}
elsif ($device =~ /^\/dev\// && ($has_volid || -d $uuid_directory)) {
	# Device is like /dev/sda1, so try to find the UUID for it by either
	# looking in /dev/disk/by-uuid or using the volid command
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
	else {
		# Use vol_id command
		local $out = &backquote_command(
				"vol_id ".quotemeta($device)." 2>&1", 1);
		if ($out =~ /ID_FS_UUID=(\S+)/) {
			$uuid = $1;
			}
		}
	}
if ($uuid && @$mounts) {
	my $found;
	foreach my $m (@$mounts) {
		if ($m->[1] eq "UUID=$uuid") {
			$found++;
			last;
			}
		}
	$uuid = undef if (!$found);
	}
return $uuid;
}

# mount_dir(directory, device, type, options)
# Mount a new directory from some device, with some options. Returns 0 if ok,
# or an error string if failed
sub mount_dir
{
local($out, $opts, $shar, %options, %smbopts);
local @opts = $_[3] eq "-" || $_[3] eq "" ? ( ) :
		grep { $_ ne "noauto" } split(/,/, $_[3]);
if ($_[2] eq "bind") {
	push(@opts, "bind");
	}
$opts = @opts ? "-o ".quotemeta(join(",", @opts)) : "";
&parse_options($_[2], $_[3]);

# Work out args for label or UUID
local $devargs;
if ($_[1] =~ /LABEL=(.*)/) {
	$devargs = "-L ".quotemeta($1);
	}
elsif ($_[1] =~ /UUID=(\S+)/) {
	$devargs = "-U ".quotemeta($1);
	}
else {
	$devargs = quotemeta($_[1]);
	}

if ($_[2] eq "swap") {
	# Use swapon to add the swap space..
	local $priarg = $options{'pri'} ne "" ? "-p $options{'pri'}" : "";
	$out = &backquote_logged("swapon $priarg $devargs 2>&1");
	if ($out =~ /Invalid argument/) {
		# looks like this swap partition isn't ready yet.. set it up
		$out = &backquote_logged("mkswap $devargs 2>&1");
		if ($?) { return "mkswap failed : <pre>$out</pre>"; }
		$out = &backquote_logged("swapon $devargs 2>&1");
		}
	if ($?) { return "<pre>$out</pre>"; }
	}
elsif ($_[2] eq "auto") {
	# Old automounter filesystem
	$out = &backquote_logged("amd $_[0] $_[1] >/dev/null 2>/dev/null");
	if ($?) { return $text{'linux_eamd'}; }
	}
elsif ($_[2] eq "autofs") {
	# New automounter filesystem
	$opts = &autofs_args($_[3]);
	$type = $_[1] !~ /^\// ? "yp" :
		(-x $_[1]) ? "program" : "file";
	$out = &backquote_logged("automount $opts $_[0] $type $_[1] 2>&1");
	if ($?) { return &text('linux_eauto', "<pre>$out</pre>"); }
	}
elsif ($_[2] eq $smbfs_fs || $_[2] eq "cifs") {
	local $shar = $_[1];
	$shar =~ s/\\/\//g if ($shar =~ /^\\/);
	local $support = $_[2] eq $smbfs_fs ? $smbfs_support : $cifs_support;
	return uc($_[2])." not supported" if (!$support);
	local $qshar = quotemeta($shar);
	if ($support >= 3) {
		# SMB filesystem mounted with mount command
		local $temp = &transname();
		local $ex = &system_logged("mount -t $_[2] $opts $qshar $_[0] >$temp 2>&1 </dev/null");
		local $out = &read_file_contents($temp);
		unlink($temp);
		if ($ex || $out =~ /failed|error/i) {
			&system_logged("umount $_[0] >/dev/null 2>&1");
			return "<pre>$out</pre>";
			}
		}
	elsif ($support == 2) {
		# SMB filesystem mounted with version 2.x smbmount
		$opts =
		    ($options{'user'} ? "-U $options{'user'} " : "").
		    ($options{'passwd'} ? "" : "-N ").
		    ($options{'workgroup'} ? "-W $options{'workgroup'} " : "").
		    ($options{'clientname'} ? "-n $options{'clientname'} " : "").
		    ($options{'machinename'} ? "-I $options{'machinename'} " : "");
		&foreign_require("proc");
		local ($fh, $fpid) = &proc::pty_process_exec_logged(
			"sh -c 'smbmount $shar $_[0] -d 0 $opts'");
		if ($options{'passwd'}) {
			local $w = &wait_for($fh, "word:");
			if ($w < 0) {
				&system_logged("umount $_[0] >/dev/null 2>&1");
				return $text{'linux_esmbconn'};
				}
			local $p = "$options{'passwd'}\n";
			syswrite($fh, $p, length($p));
			}
		local $got;
		while(<$fh>) {
			$got .= $_;
			}
		if ($got =~ /failed/) {
			&system_logged("umount $_[0] >/dev/null 2>&1");
			return "<pre>$got</pre>\n";
			}
		close($fh);
		}
	elsif ($support == 1) {
		# SMB filesystem mounted with older smbmount
		$shortname = &get_system_hostname();
		if ($shortname =~ /^([^\.]+)\.(.+)$/) { $shortname = $1; }
		$opts =
		   ($options{servername} ? "-s $options{servername} " : "").
		   ($options{clientname} ? "-c $options{clientname} "
					 : "-c $shortname ").
		   ($options{machinename} ? "-I $options{machinename} " : "").
		   ($options{user} ? "-U $options{user} " : "").
		   ($options{passwd} ? "-P $options{passwd} " : "-n ").
		   ($options{uid} ? "-u $options{uid} " : "").
		   ($options{gid} ? "-g $options{gid} " : "").
		   ($options{fmode} ? "-f $options{fmode} " : "").
		   ($options{dmode} ? "-d $options{dmode} " : "");
		$out = &backquote_logged("smbmount $shar $_[0] $opts 2>&1 </dev/null");
		if ($out) {
			&system_logged("umount $_[0] >/dev/null 2>&1");
			return "<pre>$out</pre>";
			}
		}
	&read_smbopts();
	$smbopts{$_[0]} = $_[3] eq "-" ? "dummy=1" : $_[3];
	&write_smbopts();
	}
else {
	# some filesystem supported by mount
	local $fs = $_[2] eq "*" ? "auto" : $_[2];
	$cmd = "mount -t $fs $opts $devargs ".quotemeta($_[0]);
	$out = &backquote_logged("$cmd 2>&1 </dev/null");
	if ($?) { return "<pre>$out</pre>"; }
	}
undef(@list_mounted_cache);
return 0;
}

# os_remount_dir(directory, device, type, options)
# Adjusts the options for some mounted filesystem, by re-mounting
sub os_remount_dir
{
if ($_[2] eq "swap" || $_[2] eq "auto" || $_[2] eq "autofs" ||
    $_[2] eq $smbfs_fs || $_[2] eq "cifs") {
	# Cannot use remount
	local $err = &unmount_dir(@_);
	return $err if ($err);
	return &mount_dir(@_);
	}
else {
	# Attempt to use remount
	local @opts = $_[3] eq "-" || $_[3] eq "" ? ( ) :
			grep { $_ ne "noauto" } split(/,/, $_[3]);
	push(@opts, "remount");
	local $opts = @opts ? "-o ".quotemeta(join(",", @opts)) : "";
	local $fs = $_[2] eq "*" ? "auto" : $_[2];
	if ($_[1] =~ /LABEL=(.*)/) {
		$cmd = "mount -t $fs -L $1 $opts $_[0]";
		}
	elsif ($_[1] =~ /UUID=(\S+)/) {
		$cmd = "mount -t $fs -U $1 $opts $_[0]";
		}
	else {
		$cmd = "mount -t $fs $opts $_[1] $_[0]";
		}
	$out = &backquote_logged("$cmd 2>&1 </dev/null");
	if ($?) { return "<pre>$out</pre>"; }
	undef(@list_mounted_cache);
	return undef;
	}
}

# unmount_dir(directory, device, type, options, [force])
# Unmount a directory that is currently mounted. Returns 0 if ok,
# or an error string if failed
sub unmount_dir
{
local($out, %smbopts, $dir);
if ($_[2] eq "swap") {
	# Use swapoff to remove the swap space..
	$out = &backquote_logged("swapoff $_[1]");
	if ($?) { return "<pre>$out</pre>"; }
	}
elsif ($_[2] eq "auto") {
	# Kill the amd process
	$dir = $_[0];
	if (&backquote_command("cat /etc/mtab") =~ /:\(pid([0-9]+)\)\s+$dir\s+(auto|nfs)\s+/) {
		&kill_logged('TERM', $1) || return $text{'linux_ekillamd'};
		}
	sleep(2);
	}
elsif ($_[2] eq "autofs") {
	# Kill the automount process
	$dir = $_[0];
	&backquote_command("cat /etc/mtab") =~ /automount\(pid([0-9]+)\)\s+$dir\s+autofs\s+/;
	&kill_logged('TERM', $1) || return $text{'linux_ekillauto'};
	sleep(2);
	}
else {
	local $fflag = $_[4] ? "-l" : "";
	$out = &backquote_logged("umount $fflag $_[0] 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	if ($_[2] eq $smbfs_fs || $_[2] eq "cifs") {
		# remove options from list
		&read_smbopts();
		delete($smbopts{$_[0]});
		&write_smbopts();
		&execute_command("rmmod smbfs");
		&execute_command("rmmod cifs");
		}
	}
undef(@list_mounted_cache);
return 0;
}

# can_force_unmount_dir(directory, device, type)
# Returns 1 if some directory can be forcibly un-mounted
sub can_force_unmount_dir
{
if ($_[2] ne "swap" && $_[2] ne "auto" && $_[2] ne "autofs") {
	# All filesystems using the normal 'mount' command can be
	return 1;
	}
else {
	return 0;
	}
}

# mount_modes(type)
# Given a filesystem type, returns 4 numbers that determine how the file
# system can be mounted, and whether it can be fsck'd
#  0 - cannot be permanently recorded
#	(smbfs under linux before 2.2)
#  1 - can be permanently recorded, and is always mounted at boot
#	(swap under linux)
#  2 - can be permanently recorded, and may or may not be mounted at boot
#	(most normal filesystems)
# The second is:
#  0 - mount is always permanent => mounted when saved
#	(swap under linux before 2.2, or any filesystem that is always
#	 mounted at boot by some script)
#  1 - doesn't have to be permanent
#	(normal fs types)
# The third is:
#  0 - cannot be fsck'd at boot time
#  1 - can be be fsck'd at boot
# The fourth is:
#  0 - can be unmounted
#  1 - cannot be unmounted
# The (optional) fourth is:
#  0 - can be edited
#  1 - cannot be edited (because is always mounted at boot by some script)
sub mount_modes
{
if ($_[0] eq "swap")
	{ return (1, $swaps_support ? 1 : 0, 0, 0); }
elsif ($_[0] eq "auto" || $_[0] eq "autofs")
	{ return (1, 1, 0, 0); }
elsif ($_[0] eq $smbfs_fs)
	{ return ($smbfs_support >= 3 ? 2 : 0, 1, 0, 0); }
elsif ($_[0] eq "cifs") { return (2, 1, 0, 0); }
elsif ($_[0] =~ /^ext\d+$/ || $_[0] eq "minix" ||
       $_[0] eq "xiafs" || $_[0] eq "xfs" || $_[0] eq "jfs" || $_[0] eq "btrfs")
	{ return (2, 1, 1, 0); }
else
	{ return (2, 1, 0, 0); }
}


# disk_space(type, directory)
# Returns the amount of total and free space for some filesystem, or an
# empty array if not appropriate.
sub disk_space
{
if (&get_mounted($_[1], "*") < 0) { return (); }
if ($_[0] eq "proc" || $_[0] eq "swap" ||
    $_[0] eq "auto" || $_[0] eq "autofs") { return (); }
&clean_language();
local $out = &backquote_command("df -k ".quotemeta($_[1]), 1);
&reset_environment();
if ($out =~ /Mounted on\n\S+\s+(\S+)\s+\S+\s+(\S+)/) {
	return ($1, $2);
	}
return ( );
}

# inode_space(type, directory)
# Returns the total and free number of inodes for some filesystem.
sub inode_space
{
if (&get_mounted($_[1], "*") < 0) { return (); }
&clean_language();
local $out = &backquote_command("df -i $_[1]", 1);
&reset_environment();
if ($out =~ /Mounted on\n\S+\s+(\S+)\s+\S+\s+(\S+)/) {
	return ($1, $2);
	}
return ( );
}

# list_fstypes()
# Returns an array of all the supported filesystem types. If a filesystem is
# found that is not one of the supported types, generate_location() and
# generate_options() will not be called for it.
sub list_fstypes
{
local @sup = ("ext2", "msdos", "nfs", "nfs4", "iso9660", "ext",
	      "hpfs", "fat", "vfat", "umsdos", "sysv", "reiserfs",
	      "ntfs", "hfs", "fatx");
push(@sup, $smbfs_fs) if ($smbfs_support);
push(@sup, "cifs") if ($cifs_support);
push(@sup, "auto") if ($amd_support);
push(@sup, "autofs") if ($autofs_support);
push(@sup, "tmpfs") if ($tmpfs_support);
push(@sup, "ext3") if ($ext3_support);
push(@sup, "ext4") if ($ext4_support);
push(@sup, "xfs") if ($xfs_support);
push(@sup, "btrfs") if ($btrfs_support);
push(@sup, "jfs") if ($jfs_support);
push(@sup, "bind") if ($bind_support);
push(@sup, "swap");
return @sup;
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ext2","Old Linux Native Filesystem",
	  "ext3","Linux Native Filesystem",
	  "ext4","New Linux Native Filesystem",
	  "minix","Minix Filesystem",
	  "msdos","MS-DOS Filesystem",
	  "nfs","Network Filesystem",
	  "nfs4","Network Filesystem v4",
	  $smbfs_fs,"Windows Networking Filesystem",
	  "cifs","Common Internet Filesystem",
	  "iso9660","ISO9660 CD-ROM",
	  "ext","Old EXT Linux Filesystem",
	  "xiafs","Old XIAFS Linux Filesystem",
	  "hpfs","OS/2 Filesystem",
	  "fat","MS-DOS Filesystem",
	  "vfat","Windows Filesystem",
	  "umsdos","Linux on top of MS-DOS Filesystem",
	  "sysv","System V Filesystem",
	  "swap","Virtual Memory",
	  "proc","Kernel Filesystem",
	  "sysfs","Kernel Filesystem",
	  "devpts","Pseudoterminal Device Filesystem",
	  "auto",($autofs_support ? "Old " : "")."Automounter Filesystem",
	  "reiserfs","Reiser Filesystem",
	  "autofs","New Automounter Filesystem",
	  "usbdevfs","USB Devices",
	  "shm","SysV Shared Memory",
	  "tmpfs","RAM/Swap Disk",
	  "devtmpfs","RAM/Swap Disk",
	  "ramfs","RAM Disk",
	  "btrfs","Oracle B-Tree Filesystem",
	  "ocfs2","Oracle Clustering Filesystem",
	  "gfs2","RedHat Clustering Filesystem",
	  "xfs","Linux XFS Filesystem",
	  "jfs","IBM Journalling Filesystem",
	  "ntfs","Windows NT Filesystem",
	  "bind","Loopback Filesystem",
	  "hfs","Apple Filesystem",
	  "fatx","XBOX Filesystem",
	  "btrfs","BTR Filesystem",
	  );
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return ($_[0] eq "nfs" || $_[0] eq "nfs4" || $_[0] eq "auto" ||
	$_[0] eq "autofs" || $_[0] eq "bind" || $_[0] eq "tmpfs");
}


# generate_location(type, location)
# Output HTML for editing the mount location of some filesystem.
sub generate_location
{
local ($type, $loc) = @_;
if ($type eq "nfs" || $type eq "nfs4") {
	# NFS mount from some host and directory
	local ($host, $dir) = $loc =~ /^([^:]+):(.*)$/ ? ( $1, $2 ) : ( );
	print &ui_table_row(&hlink($text{'linux_nfshost'}, "nfshost"),
		&ui_textbox("nfs_host", $host, 30).
		&nfs_server_chooser_button("nfs_host").
		"&nbsp;".
		"<b>".&hlink($text{'linux_nfsdir'}, "nfsdir")."</b> ".
		&ui_textbox("nfs_dir", 
	       		    ($type eq "nfs4") && ($dir eq "") ? "/" : $dir, 30).
		&nfs_export_chooser_button("nfs_host", "nfs_dir"));
	}
elsif ($type eq "auto") {
	# Using some automounter map
	print &ui_table_row($text{'linux_map'},
		&ui_textbox("auto_map", $loc, 30)." ".
		&file_chooser_button("auto_map", 0));
	}
elsif ($type eq "autofs") {
	# Using some kernel automounter map
	print &ui_table_row($text{'linux_map'},
		&ui_textbox("autofs_map", $loc, 30)." ".
		&file_chooser_button("autofs_map", 0));
	}
elsif ($type eq "swap") {
	# Swap file or device
	&foreign_require("fdisk");
	local @opts;
	local ($found, $ufound, $lnx_dev);

	# Show partitions input
	local $sel = &fdisk::partition_select("lnx_disk", $loc, 3, \$found);
	push(@opts, [ 0, $text{'linux_disk'}, $sel ]);
	$lnx_dev = 0 if ($found);

	# Show UUID input
	if ($has_volid || -d $uuid_directory) {
		local $u = $loc =~ /UUID=(\S+)/ ? $1 : undef;
		local $usel = &fdisk::volid_select("lnx_uuid", $u, \$ufound);
		if ($usel) {
			push(@opts, [ 5, $text{'linux_usel'}, $usel ]);
			$lnx_dev = 5 if ($ufound);
			}
		}

	# Show other file input
	$lnx_dev = 1 if (!$found && !$ufound);
	push(@opts, [ 1, $text{'linux_swapfile'},
			 &ui_textbox("lnx_other", $loc, 40)." ".
			 &file_chooser_button("lnx_other") ]);
	print &ui_table_row($text{'linux_swapfile'},
		&ui_radio_table("lnx_dev", $lnx_dev, \@opts));
	}
elsif ($type eq $smbfs_fs || $type eq "cifs") {
	# Windows filesystem
	local ($server, $share) = $loc =~ /^\\\\([^\\]*)\\(.*)$/ ?
					($1, $2) : ( );
	print &ui_table_row($text{'linux_smbserver'},
		&ui_textbox("smbfs_server", $server, 30)." ".
		&smb_server_chooser_button("smbfs_server")." ".
		"&nbsp;".
		"<b>$text{'linux_smbshare'}</b> ".
		&ui_textbox("smbfs_share", $share, 30)." ".
		&smb_share_chooser_button("smbfs_server", "smbfs_share"));
	}
elsif ($type eq "tmpfs") {
	# RAM disk (no location needed)
	}
elsif ($type eq "bind") {
	# Loopback filesystem, mounted from some other directory
	print &ui_table_row($text{'linux_bind'},
		&ui_textbox("bind_dir", $loc, 40)." ".
		&file_chooser_button("bind_dir", 1));
	}
else {
	# This is some linux disk-based filesystem
	&foreign_require("fdisk");
	local ($found, $rfound, $lfound, $vfound, $ufound, $rsel, $c);
	local ($lnx_dev, @opts);

	# Show regular partition input
	local $sel = &fdisk::partition_select("lnx_disk", $loc, 0, \$found);
	push(@opts, [ 0, $text{'linux_disk'}, $sel ]);
	$lnx_dev = 0 if ($found);

	# Show RAID input
	if (&foreign_check("raid")) {
		&foreign_require("raid");
		local $conf = &raid::get_raidtab();
		local @ropts;
		foreach $c (@$conf) {
			if ($c->{'active'}) {
				$c->{'value'} =~ /(\d+)$/;
				push(@ropts, [ $c->{'value'},
					       &text('linux_rdev', "$1") ]);
				$rfound++ if ($loc eq $c->{'value'});
				}
			}
		$lnx_dev = 2 if ($rfound);
		if (@ropts) {
			push(@opts, [ 2, $text{'linux_raid'},
				&ui_select("lnx_raid", $loc, \@ropts) ]);
			}
		}

	# Show LVM input
	if (&foreign_check("lvm")) {
		&foreign_require("lvm");
		local @vgs = &lvm::list_volume_groups();
		local @lvs;
		foreach $v (@vgs) {
			push(@lvs, &lvm::list_logical_volumes($v->{'name'}));
			}
		local @lopts;
		foreach $l (@lvs) {
			local $sf = &same_file($loc, $l->{'device'});
			push(@lopts, [ $l->{'device'},
			    &text('linux_ldev', $l->{'vg'}, $l->{'name'}) ]);
			$vfound = $l->{'device'} if ($sf);
			}
		$lnx_dev = 4 if ($vfound);
		if (@lopts) {
			push(@opts, [ 4, $text{'linux_lvm'},
				&ui_select("lnx_lvm", $vfound, \@lopts) ]);
			}
		}

	# Show label input
	if ($has_e2label || $has_xfs_db || $has_reiserfstune) {
		local $l = $_[1] =~ /LABEL=(.*)/ ? $1 : undef;
		local $esel = &fdisk::label_select("lnx_label", $l, \$lfound);
		if ($esel) {
			push(@opts, [ 3, $text{'linux_lsel'}, $esel ]);
			$lnx_dev = 3 if ($lfound);
			}
		}

	# Show UUID input
	if ($has_volid || -d $uuid_directory) {
		local $u = $loc =~ /UUID=(\S+)/ ? $1 : undef;
		local $usel = &fdisk::volid_select("lnx_uuid", $u, \$ufound);
		if ($usel) {
			push(@opts, [ 5, $text{'linux_usel'}, $usel ]);
			$lnx_dev = 5 if ($ufound);
			}
		}

	# Show other device input
	local $anyfound = $found || $rfound || $lfound || $vfound || $ufound;
	$lnx_dev = 1 if (!$anyfound);
	push(@opts, [ 1, $text{'linux_other'},
		      &ui_textbox("lnx_other", $anyfound ? "" : $loc, 40).
		      " ".&file_chooser_button("lnx_other") ]);

	print &ui_table_row(&fstype_name($_[0]),
		&ui_radio_table("lnx_dev", $lnx_dev, \@opts));
	}
}


# generate_options(type, newmount)
# Output HTML for editing mount options for a particular filesystem 
# under this OS
sub generate_options
{
local ($type, $newmount) = @_;
if ($type ne "swap" && $type ne "auto" &&
    $type ne "autofs" && $type ne $smbfs_fs && $type ne "cifs") {
	# Lots of options are common to all linux filesystems
	print &ui_table_row(&hlink($text{'linux_ro'}, "linux_ro"),
		&ui_yesno_radio("lnx_ro", defined($options{"ro"})));

	print &ui_table_row(&hlink($text{'linux_sync'}, "linux_sync"),
		&ui_yesno_radio("lnx_sync", defined($options{"sync"}), 0, 1));

	print &ui_table_row(&hlink($text{'linux_user'}, "linux_user"),
		&ui_yesno_radio("lnx_user", defined($options{"user"})));

	print &ui_table_row(&hlink($text{'linux_nodev'}, "linux_nodev"),
		&ui_radio("lnx_nodev", defined($options{"nodev"}) ? 1 :
				       defined($options{"dev"}) ? 0 : 2,
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ],
			    [ 2, $text{'linux_ifuser'} ] ]));

	print &ui_table_row(&hlink($text{'linux_noexec'}, "linux_noexec"),
		&ui_radio("lnx_noexec", defined($options{"noexec"}) ? 1 :
				       defined($options{"dev"}) ? 0 : 2,
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ],
			    [ 2, $text{'linux_ifuser'} ] ]));

	print &ui_table_row(&hlink($text{'linux_nosuid'}, "linux_nosuid"),
		&ui_radio("lnx_nosuid", defined($options{"nosuid"}) ? 1 :
				       defined($options{"dev"}) ? 0 : 2,
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ],
			    [ 2, $text{'linux_ifuser'} ] ]));

	print &ui_table_row(&hlink($text{'linux_noatime'}, "linux_noatime"),
		&ui_yesno_radio("lnx_noatime", defined($options{"noatime"})));

	print &ui_table_row(&hlink($text{'linux_netdev'}, "linux_netdev"),
		&ui_yesno_radio("lnx_netdev", defined($options{"_netdev"})));
	}
	
if ($type =~ /^ext\d+$/) {
	# Ext2+ has lots more options..
	print &ui_table_hr();

	if ($no_mount_check) {
		print &ui_table_row($text{'linux_df'},
		    &ui_yesno_radio("ext2_df", defined($options{"minixdf"})));
		}
	else {
		print &ui_table_row($text{'linux_check'},
			&ui_select("ext2_check",
			    $options{"check"} eq "" ? "normal" :
			    defined($options{"nocheck"}) ? "none" :
						       $options{"check"},
			    [ [ "normal", $text{'linux_normal'} ],
			      [ "strict", $text{'linux_strict'} ],
			      [ "none", $text{'linux_none'} ] ]));
		}

	print &ui_table_row($text{'linux_errors'},
		&ui_select("ext2_errors",
			!defined($options{"errors"}) ? "default" :
			$options{"errors"},
			[ [ "default", $text{'default'} ],
			  [ "continue", $text{'linux_continue'} ],
			  [ "remount-ro", $text{'linux_remount_ro'} ],
			  [ "panic", $text{'linux_panic'} ] ]));

	print &ui_table_row($text{'linux_grpid'},
		&ui_yesno_radio("ext2_grpid", defined($options{"grpid"}) ||
					      defined($options{"bsdgroups"})));

	my $usrquota = defined($options{"usrquota"}) ||
			defined($options{"usrjquota"});
	my $grpquota = defined($options{"grpquota"}) ||
			defined($options{"grpjquota"});
	print &ui_table_row($text{'linux_quotas'},
		&ui_select("ext2_quota", $usrquota && $grpquota ? 3 :
					 $grpquota ? 2 :
					 $usrquota ? 1 : 0,
			   [ [ 0, $text{'no'} ],
			     [ 1, $text{'linux_usrquota'} ],
			     [ 2, $text{'linux_grpquota'} ],
			     [ 3, $text{'linux_usrgrpquota'} ] ]));

	print &ui_table_row($text{'linux_quotaj'},
		&ui_radio("ext2_quotaj",
			  defined($options{"usrjquota"}) ||
			   defined($options{"grpjquota"}) ? 1 : 0,
			  [ [ 1, $text{'linux_quotaj1'} ],
			    [ 0, $text{'linux_quotaj0'} ] ]));

	print &ui_table_row($text{'linux_resuid'},
		&ui_user_textbox("ext2_resuid", defined($options{"resuid"}) ?
				   getpwuid($options{"resuid"}) : ""));

	print &ui_table_row($text{'linux_resgid'},
		&ui_group_textbox("ext2_resgid", defined($options{"resgid"}) ?
				   getgrgid($options{"resgid"}) : ""));
	}
elsif ($type eq "nfs" || $type eq "nfs4") {
	# Linux nfs has some more options...
	print &ui_table_hr();

	print &ui_table_row(&hlink($text{'linux_port'}, "linux_port"),
		&ui_opt_textbox("nfs_port", $options{"port"}, 6,
				$text{'default'}));

	print &ui_table_row(&hlink($text{'linux_bg'}, "linux_bg"),
		&ui_yesno_radio("nfs_bg", defined($options{"bg"})));

	print &ui_table_row(&hlink($text{'linux_soft'}, "linux_soft"),
		&ui_yesno_radio("nfs_soft", defined($options{"soft"})));

	print &ui_table_row(&hlink($text{'linux_timeo'}, "linux_timeo"),
		&ui_opt_textbox("nfs_timeo", $options{"timeo"}, 6,
				$text{'default'}));

	print &ui_table_row(&hlink($text{'linux_retrans'}, "linux_retrans"),
		&ui_opt_textbox("nfs_retrans", $options{"restrans"}, 6,
				$text{'default'}));
	
	print &ui_table_row(&hlink($text{'linux_intr'}, "linux_intr"),
		&ui_yesno_radio("nfs_intr", defined($options{"intr"})));

	local $proto = defined($options{"udp"}) ? "udp" :
		       defined($options{"tcp"}) ? "tcp" : "";
	print &ui_table_row(&hlink($text{'linux_transfert'}, "linux_transfert"),
		&ui_select("nfs_transfert", $proto,
			   [ [ '', $text{'default'} ],
			     [ 'tcp', 'TCP' ],
			     [ 'udp', 'UDP' ] ]));

	print &ui_table_row(&hlink($text{'linux_rsize'}, "linux_rsize"),
		&ui_opt_textbox("nfs_rsize", $options{"rsize"}, 6,
				$text{'default'}));

	print &ui_table_row(&hlink($text{'linux_wsize'}, "linux_wsize"),
		&ui_opt_textbox("nfs_wsize", $options{"wsize"}, 6,
				$text{'default'}));

	my ($auth, $sec) = $options{"sec"} =~ /^(ntlmssp|ntlmv2|ntlm|spkm|lkey|krb5|sys)(p|i|)/ ? ($1, $2) : ( );
	print &ui_table_row(&hlink($text{'linux_auth'}, "linux_auth"),
		&ui_radio("nfs_auth", $auth,
			  [ [ '', 'sys' ],
			    [ 'krb5', 'krb5 (Kerberos 5)' ],
			    [ 'lkey', 'lkey' ],
			    [ 'spkm', 'spkm-3' ],
			    [ 'ntlm', 'ntlm (NTLM)' ],
			    [ 'ntmlv2', 'ntmlv2 (NTLM version 2)' ],
			    [ 'ntlmssp', 'ntlmssp (NTLMv2 in NTLMSSP)' ] ]));

	print &ui_table_row(&hlink($text{'linux_sec'}, "linux_sec"),
		&ui_radio("nfs_sec", $sec,
			  [ [ '', $text{'config_none'} ],
			    [ 'i', $text{'linux_integrity'} ],
			    [ 'p', $text{'linux_privacy'} ] ]));

	print &ui_table_row(&hlink($text{'linux_nfsvers'}, "linux_nfsvers"),
		&ui_select("nfs_nfsvers", $options{"nfsvers"},
			   [ [ "", $text{'linux_nfsdefault'} ],
			     2, 3, 4, 4.1 ]));
	}
elsif ($type eq "fat" || $type eq "vfat" || $type eq "msdos" ||
       $type eq "umsdos" || $type eq "fatx"){
	# All dos-based filesystems share some options
	print &ui_table_hr();

	print &ui_table_row($text{'linux_uid'},
		&ui_user_textbox("fat_uid", defined($options{'uid'}) ?
					      getpwuid($options{'uid'}) : ""));

	print &ui_table_row($text{'linux_gid'},
		&ui_group_textbox("fat_gid", defined($options{'gid'}) ?
					      getgrgid($options{'gid'}) : ""));

	print &ui_table_row($text{'linux_rules'},
		&ui_select("fat_check", substr($options{"check"}, 0, 1),
			   [ [ '', $text{'default'} ],
			     [ 'r', $text{'linux_relaxed'} ],
			     [ 'n', $text{'linux_normal'} ],
			     [ 's', $text{'linux_strict'} ] ]));

	$conv = substr($options{"conv"}, 0, 1);
	$conv = '' if ($conv eq 'b');
	print &ui_table_row($text{'linux_conv'},
		&ui_select("fat_conv", $conv,
			   [ [ 'b', $text{'linux_none'} ],
			     [ 't', $text{'linux_allfiles'} ],
			     [ 'a', $text{'linux_textfiles'} ] ]));

	print &ui_table_row($text{'linux_umask'},
		&ui_opt_textbox("fat_umask", $options{"umask"}, 6,
				$text{'default'}));

	print &ui_table_row($text{'linux_quiet'},
		&ui_yesno_radio("fat_quiet", defined($options{"quiet"}), 0, 1));


	if ($_[0] eq "vfat") {
		# vfat has some extra options beyond fat
		print &ui_table_row($text{'linux_uni_xlate'},
			&ui_yesno_radio("fat_uni_xlate",
					defined($options{"uni_xlate"})));

		print &ui_table_row($text{'linux_posix'},
			&ui_yesno_radio("fat_posix",
					defined($options{"posix"})));
		}
	}
elsif ($type eq "hpfs") {
	# OS/2 filesystems has some more options..
	print &ui_table_hr();

	print &ui_table_row($text{'linux_uid'},
		&ui_user_textbox("hpfs_uid", defined($options{'uid'}) ?
					      getpwuid($options{'uid'}) : ""));

	print &ui_table_row($text{'linux_gid'},
		&ui_group_textbox("hpfs_gid", defined($options{'gid'}) ?
					      getgrgid($options{'gid'}) : ""));

	print &ui_table_row($text{'linux_umask'},
		&ui_opt_textbox("hpfs_umask", $options{"umask"}, 6,
				$text{'default'}));

	print &ui_table_row($text{'linux_conv2'},
		&ui_select("hpfs_conv", substr($options{"conv"}, 0, 1) || "b",
			   [ [ 'b', $text{'linux_none'} ],
			     [ 't', $text{'linux_allfiles'} ],
			     [ 'a', $text{'linux_textfiles'} ] ]));
	}
elsif ($type eq "iso9660") {
	# CD-ROM filesystems have some more options..
	print &ui_table_hr();

	print &ui_table_row($text{'linux_uid'},
		&ui_user_textbox("iso9660_uid", defined($options{'uid'}) ?
					      getpwuid($options{'uid'}) : ""));

	print &ui_table_row($text{'linux_gid'},
		&ui_group_textbox("iso9660_gid", defined($options{'gid'}) ?
					      getgrgid($options{'gid'}) : ""));

	print &ui_table_row($text{'linux_rock'},
		&ui_yesno_radio("iso9660_norock", defined($options{"norock"})));

	print &ui_table_row($text{'linux_mode'},
		&ui_textbox("iso9660_mode", defined($options{"mode"}) ?
				$options{"mode"} : "444", 10));
	}
elsif ($type eq "auto") {
	# Don't know how to set options for auto filesystems yet..
	print &ui_table_span("<i>$text{'linux_noopts'}</i>");
	}
elsif ($_[0] eq "autofs") {
	print &ui_table_span("<b>$text{'edit_autofs_opt'}</b>");

	print &ui_table_row($text{'linux_timeout'},
		&ui_opt_textbox("autofs_timeout", $options{'timeout'}, 6,
				$text{'default'}));

	print &ui_table_row($text{'linux_pid_file'},
		&ui_opt_textbox("autofs_pid-file", $options{'pid-file'}, 40,
				$text{'no'}, $text{'yes'})." ".
		&file_chooser_button("autofs_pid-file", 0), 3);
	}
elsif ($type eq "swap") {
	# Swap has no options..
	print &ui_table_row($text{'linux_swappri'},
		&ui_opt_textbox("swap_pri", $options{'pri'}, 6,
				     $text{'default'}));
	}
elsif ($type eq $smbfs_fs || $type eq "cifs") {
	# SMB filesystems have a few options..
	$support = $_[0] eq $smbfs_fs ? $smbfs_support : $cifs_support;
	if (keys(%options) == 0 && !$_[1]) {
		print &ui_table_span("<i>$text{'linux_smbwarn'}</i>");
		}

	print &ui_table_row($text{'linux_username'},
		&ui_textbox("smbfs_user",
		$support == 4 ? $options{'username'} : $options{'user'}, 20));

	print &ui_table_row($text{'linux_password'},
		&ui_password("smbfs_passwd",
		$support == 4 ? $options{'password'} : $options{'passwd'}, 20));
	
	if ($support == 4) {
		print &ui_table_row($text{'linux_credentials'},
			&ui_textbox("smbfs_creds", $options{"credentials"}, 30).
			" ".
			($access{'browse'} ?
			  &file_chooser_button("smbfs_creds", 0) : ""));
		}

	if ($support != 2) {
		print &ui_table_row($text{'linux_uid'},
			&ui_user_textbox("smbfs_uid",
			  defined($options{'uid'}) ? getpwuid($options{'uid'})
						   : ""));

		print &ui_table_row($text{'linux_gid'},
			&ui_group_textbox("smbfs_gid",
			  defined($options{'gid'}) ? getgrgid($options{'gid'})
						   : ""));
		}

	if ($support == 1) {
		print &ui_table_row($text{'linux_sname'},
			&ui_opt_textbox("smbfs_sname", $options{"servername"},
					20, $text{'linux_auto'}));
		}
	elsif ($support == 2) {
		print &ui_table_row($text{'linux_wg'},
			&ui_opt_textbox("smbfs_wg", $options{"workgroup"},
					20, $text{'linux_auto'}));
		}

	if ($support < 3) {
		print &ui_table_row($text{'linux_cname'},
			&ui_opt_textbox("smbfs_cname", $options{"clientname"},
					20, $text{'linux_auto'}));

		print &ui_table_row($text{'linux_mname'},
			&ui_opt_textbox("smbfs_mname", $options{"machinename"},
					20, $text{'linux_auto'}));
		}
	
	if ($support == 1) {
		print &ui_table_row($text{'linux_fmode'},
		    &ui_textbox("smbfs_fmode",
			defined($options{'fmode'}) ? $options{'fmode'} : "755",
			5));

		print &ui_table_row($text{'linux_dmode'},
		    &ui_textbox("smbfs_dmode",
			defined($options{'dmode'}) ? $options{'dmode'} : "755",
			5));
		}
	elsif ($support >= 3) {
		print &ui_table_row($text{'linux_fmode'},
			&ui_opt_textbox("smbfs_file_mode",
					$options{'file_mode'}, 5,
					$text{'default'}));

		print &ui_table_row($text{'linux_dmode'},
			&ui_opt_textbox("smbfs_dir_mode",
					$options{'dir_mode'}, 5,
					$text{'default'}));

		print &ui_table_row($text{'linux_ro'},
			&ui_yesno_radio("smbfs_ro", defined($options{"ro"})));
		}
	if ($support == 4) {
		print &ui_table_row($text{'linux_user'},
		    &ui_yesno_radio("smbfs_user2", defined($options{"user"})));

		print &ui_table_row($text{'linux_cname'},
			&ui_opt_textbox("smbfs_cname", $options{"netbiosname"},
					40, $text{'linux_auto'}), 3);

		print &ui_table_row($text{'linux_mname'},
			&ui_opt_textbox("smbfs_mname", $options{"ip"},
					40, $text{'linux_auto'}), 3);

		print &ui_table_row($text{'linux_wg'},
			&ui_opt_textbox("smbfs_wg", $options{"workgroup"},
					10, $text{'linux_auto'}));

		}

	if ($type eq "cifs") {
		# Show cifs-only options
		print &ui_table_row($text{'linux_codepage'},
			&ui_opt_textbox("smbfs_codepage",
			    $options{'codepage'}, 10, $text{'default'}));

		print &ui_table_row($text{'linux_iocharset'},
			&ui_opt_textbox("smbfs_iocharset",
			    $options{'iocharset'}, 10, $text{'default'}));

		print &ui_table_row($text{'linux_nounix'},
			&ui_yesno_radio("smbfs_nounix",
					defined($options{"nounix"})));

		print &ui_table_row($text{'linux_cvers'},
			&ui_opt_textbox("smbfs_vers", $options{"vers"},
					5, $text{'linux_auto'}));
		}
	}
elsif ($type eq "reiserfs") {
	# Reiserfs is a new super-efficient filesystem
	print &ui_table_hr();

	print &ui_table_row($text{'linux_notail'},
		&ui_yesno_radio("lnx_notail", defined($options{"notail"})));
	}
elsif ($type eq "tmpfs") {
	# Tmpfs has some size options
	print &ui_table_hr();

	print &ui_table_row($text{'linux_tmpsize'},
		&ui_opt_textbox("lnx_tmpsize", $options{"size"}, 10,
				$text{'linux_unlimited'})." bytes");

	print &ui_table_row($text{'linux_nr_blocks'},
		&ui_opt_textbox("lnx_nr_blocks", $options{"nr_blocks"}, 10,
				$text{'linux_unlimited'}));

	print &ui_table_row($text{'linux_nr_inodes'},
		&ui_opt_textbox("lnx_nr_inodes", $options{"nr_inodes"}, 10,
				$text{'linux_unlimited'}));

	print &ui_table_row($text{'linux_tmpmode'},
		&ui_opt_textbox("lnx_tmpmode", $options{"mode"}, 3,
				$text{'default'}));
	}
elsif ($type eq "xfs") {
	# Show options for XFS
	print &ui_table_hr();

	print &ui_table_row($text{'linux_usrquotas'},
		&ui_radio("xfs_usrquota",
			defined($options{"quota"}) ||
			  defined($options{"usrquota"}) ? 1 :
			defined($options{"uqnoenforce"}) ? 2 : 0,
			[ [ 1, $text{'yes'} ],
			  [ 2, $text{'linux_noenforce'} ],
			  [ 0, $text{'no'} ] ]));

	print &ui_table_row($text{'linux_grpquotas'},
		&ui_radio("xfs_grpquota",
			defined($options{"quota"}) ||
			  defined($options{"grpquota"}) ? 1 :
			defined($options{"uqnoenforce"}) ? 2 : 0,
			[ [ 1, $text{'yes'} ],
			  [ 2, $text{'linux_noenforce'} ],
			  [ 0, $text{'no'} ] ]));
	}
elsif ($type eq "jfs") {
	# No other JFS options yet!
	}
elsif ($type eq "ntfs") {
	# Windows NT/XP/2000 filesystem
	print &ui_table_hr();

	print &ui_table_row($text{'linux_uid'},
		&ui_user_textbox("ntfs_uid", defined($options{'uid'}) ?
					      getpwuid($options{'uid'}) : ""));

	print &ui_table_row($text{'linux_gid'},
		&ui_group_textbox("ntfs_gid", defined($options{'gid'}) ?
					      getgrgid($options{'gid'}) : ""));
	}
}


# check_location(type)
# Parse and check inputs from %in, calling &error() if something is wrong.
# Returns the location string for storing in the fstab file
sub check_location
{
if (($_[0] eq "nfs") || ($_[0] eq "nfs4")) {
	local($out, $temp, $mout, $dirlist, @dirlist);

	if (&has_command("showmount") && $config{'nfs_check'}) {
		# Use ping and showmount to see if the host exists and is up
		if ($in{nfs_host} !~ /^\S+$/) {
			&error(&text('linux_ehost', $in{'nfs_host'}));
			}
		$out = &backquote_command(
			"ping -c 1 ".quotemeta($in{nfs_host})." 2>&1");
		if ($out =~ /unknown host/) {
			&error(&text('linux_ehost2', $in{'nfs_host'}));
			}
		elsif ($out =~ /100\% packet loss/) {
			&error(&text('linux_edown', $in{'nfs_host'}));
			}
		$out = &backquote_command(
			"showmount -e ".quotemeta($in{nfs_host})." 2>&1");
		if ($out =~ /Unable to receive/) {
			&error(&text('linux_enfs', $in{'nfs_host'}));
			}
		elsif ($?) {
			&error(&text('linux_elist', $out));
			}
		}

	# Validate directory name for NFSv3 (in v4 '/' exists)
	foreach (split(/\n/, $out)) {
		if (/^(\/\S+)/) {
			$dirlist .= "$1\n";
			push(@dirlist, $1);
			}
		}
	
	if ($_[0] ne "nfs4" && $in{'nfs_dir'} !~ /^\/.*$/ &&
	    &indexof($in{'nfs_dir'}, @dirlist) < 0) {
		&error(&text('linux_enfsdir', $in{'nfs_dir'},
			     $in{'nfs_host'}, "<pre>$dirlist</pre>"));
		}

	# Try a test mount to see if filesystem is available
	$temp = &tempname();
	&make_dir($temp, 0755);
	&execute_command("mount -t $_[0] ".
			 quotemeta("$in{nfs_host}:$in{nfs_dir}")." ".
			 quotemeta($temp),
			 undef, \$mout, \$mout);
	if ($mout =~ /No such file or directory/i) {
		&error(&text('linux_enfsdir', $in{'nfs_dir'},
			     $in{'nfs_host'}, "<pre>$dirlist</pre>"));
		}
	elsif ($mout =~ /Permission denied/i) {
		&error(&text('linux_enfsperm', $in{'nfs_dir'}, $in{'nfs_host'}));
		}
	elsif ($?) {
		&error(&text('linux_enfsmount', "<tt>$mout</tt>"));
		}
	# It worked! unmount
	local $umout;
	&execute_command("umount ".quotemeta($temp), undef, \$umout, \$umout);
	if ($?) {
		&error(&text('linux_enfsmount', "<tt>$umout</tt>"));
		}
	rmdir(&translate_filename($temp));	# Don't delete mounted files!

	return "$in{nfs_host}:$in{nfs_dir}";
	}
elsif ($_[0] eq "auto") {
	# Check if the automounter map exists..
	(-r $in{auto_map}) || &error(&text('linux_eautomap', $in{'auto_map'}));
	return $in{auto_map};
	}
elsif ($_[0] eq "autofs") {
	# Check if the map exists (if it is a file)
	if ($in{'autofs_map'} =~ /^\// && !(-r $in{'autofs_map'})) {
		&error(&text('linux_eautomap', $in{'autofs_map'}));
		}
	return $in{autofs_map};
	}
elsif ($_[0] eq $smbfs_fs || $_[0] eq "cifs") {
	# No real checking done
	$in{'smbfs_server'} =~ /\S/ || &error($text{'linux_eserver'});
	$in{'smbfs_share'} =~ /\S/ || &error($text{'linux_eshare'});
	return &lowercase_share_path(
		"\\\\".$in{'smbfs_server'}."\\".$in{'smbfs_share'});
	}
elsif ($_[0] eq "tmpfs") {
	# No location needed
	return "tmpfs";
	}
elsif ($_[0] eq "bind") {
	# Just check the directory
	-d $in{'bind_dir'} || &error($text{'linux_ebind'});
	return $in{'bind_dir'};
	}
else {
	# This is some kind of disk-based linux filesystem.. get the device name
	if ($in{'lnx_dev'} == 0) {
		$dv = $in{'lnx_disk'};
		}
	elsif ($in{'lnx_dev'} == 2) {
		$dv = $in{'lnx_raid'};
		}
	elsif ($in{'lnx_dev'} == 3) {
		$dv = "LABEL=".$in{'lnx_label'};
		}
	elsif ($in{'lnx_dev'} == 4) {
		$dv = $in{'lnx_lvm'};
		}
	elsif ($in{'lnx_dev'} == 5) {
		$dv = "UUID=".$in{'lnx_uuid'};
		}
	else {
		$dv = $in{'lnx_other'};
		$dv || &error($text{'linux_edev'});
		}

	# If the device entered is a symlink, follow it
	#if ($dvlink = readlink($dv)) {
	#	if ($dvlink =~ /^\//) { $dv = $dvlink; }
	#	else {	$dv =~ /^(.*\/)[^\/]+$/;
	#		$dv = $1.$dvlink;
	#		}
	#	}

	# Check if the device actually exists and uses the right filesystem
	if (!-r $dv && $dv !~ /LABEL=/ && $dv !~ /UUID=/) {
		if ($_[0] eq "swap" && $dv !~ /\/dev/) {
			&swap_form($dv);
			}
		else {
			&error(&text('linux_edevfile', $dv));
			}
		}
	return $dv;
	}
}

# check_options(type, device, directory)
# Read options for some filesystem from %in, and use them to update the
# %options array. Options handled by the user interface will be set or
# removed, while unknown options will be left untouched.
sub check_options
{
local($k, @rv);

# Parse the common options first..
if ($_[0] ne "swap" && $_[0] ne "auto" &&
    $_[0] ne "autofs" && $_[0] ne $smbfs_fs && $_[0] ne "cifs") {
	delete($options{"ro"}); delete($options{"rw"});
	if ($in{lnx_ro}) { $options{"ro"} = ""; }

	delete($options{"sync"}); delete($options{"async"});
	if ($in{lnx_sync}) { $options{"sync"} = ""; }

	delete($options{"dev"}); delete($options{"nodev"});
	if ($in{lnx_nodev} == 1) { $options{"nodev"} = ""; }
	elsif ($in{lnx_nodev} == 0) { $options{"dev"} = ""; }

	delete($options{"exec"}); delete($options{"noexec"});
	if ($in{lnx_noexec} == 1) { $options{"noexec"} = ""; }
	elsif ($in{lnx_noexec} == 0) { $options{"exec"} = ""; }

	delete($options{"suid"}); delete($options{"nosuid"});
	if ($in{lnx_nosuid} == 1) { $options{"nosuid"} = ""; }
	elsif ($in{lnx_nosuid} == 0) { $options{"suid"} = ""; }

	delete($options{"user"}); delete($options{"nouser"});
	if ($in{lnx_user}) { $options{"user"} = ""; }

	delete($options{"noatime"});
	$options{"noatime"} = "" if ($in{'lnx_noatime'});
	delete($options{"relatime"}) if ($in{'lnx_noatime'});

	delete($options{"_netdev"});
	$options{"_netdev"} = "" if ($in{'lnx_netdev'});
	}

if (($_[0] eq "nfs") || ($_[0] eq "nfs4")) {
	# NFS has a few specific options..
	delete($options{"bg"}); delete($options{"fg"});
	if ($in{nfs_bg}) { $options{"bg"} = ""; }

	delete($options{"soft"}); delete($options{"hard"});
	if ($in{nfs_soft}) { $options{"soft"} = ""; }

	delete($options{"timeo"});
	if (!$in{nfs_timeo_def}) {
		$in{nfs_timeo} =~ /^\d+$/ && $in{nfs_timeo} > 0 ||
			&error($text{'linux_etimeo'});
		$options{"timeo"} = $in{nfs_timeo};
		}

	delete($options{"retrans"});
	if (!$in{nfs_retrans_def}) { $options{"retrans"} = $in{nfs_retrans}; }

	delete($options{"port"});
	if (!$in{nfs_port_def}) { $options{"port"} = $in{nfs_port}; }

	delete($options{"intr"}); delete($options{"nointr"});
	if ($in{nfs_intr}) { $options{"intr"} = ""; }

	delete($options{"tcp"}); delete($options{"udp"});
	if ($in{nfs_transfert} eq "tcp") {
		$options{"tcp"} = "";
		}
	elsif ($in{nfs_transfert} eq "udp") {
		$options{"udp"} = "";
		}

	delete($options{"wsize"});
	if (!$in{nfs_wsize_def}) { $options{"wsize"} = $in{nfs_wsize}; }

	delete($options{"rsize"});
	if (!$in{nfs_rsize_def}) { $options{"rsize"} = $in{nfs_rsize}; }

	delete($options{"sec"});

	# Only sys and krb5 for the moment
	if ($in{nfs_auth}) {
	    $options{"sec"} = $in{"nfs_auth"}.$in{"nfs_sec"};
	}

	if ($in{'nfs_nfsvers'}) {
		$options{'nfsvers'} = $in{'nfs_nfsvers'};
	} else {
		delete($options{'nfsvers'});
	}
    }
elsif ($_[0] =~ /^ext\d+$/) {
	# More options for ext2..
	if ($no_mount_check) {
		delete($options{"bsddf"}); delete($options{"minixdf"});
		$options{"minixdf"} = "" if ($in{'ext2_df'});
		}
	else {
		delete($options{"check"}); delete($options{"nocheck"});
		if ($in{ext2_check} ne "normal") {
			$options{"check"} = $in{ext2_check};
			}
		}

	delete($options{"errors"});
	if ($in{ext2_errors} ne "default") {
		$options{"errors"} = $in{ext2_errors};
		}

	delete($options{"grpid"}); delete($options{"bsdgroups"});
	delete($options{"sysvgroups"}); delete($options{"nogrpid"});
	if ($in{ext2_grpid}) {
		$options{"grpid"} = "";
		}

	delete($options{"resuid"}); delete($options{"resgid"});
	if ($in{'ext2_resuid'})
		{ $options{"resuid"} = getpwnam($in{'ext2_resuid'}); }
	if ($in{'ext2_resgid'})
		{ $options{"resgid"} = getgrnam($in{'ext2_resgid'}); }

	my $jufile = $options{"usrjquota"};
	my $jgfile = $options{"grpjquota"};
	delete($options{"quota"}); delete($options{"noquota"});
	delete($options{"usrquota"}); delete($options{"grpquota"});
	delete($options{"usrjquota"}); delete($options{"grpjquota"});
	my ($u, $g) = ("usrquota", "grpquota");
	if ($in{'ext2_quotaj'}) {
		($u, $g) = ("usrjquota", "grpjquota");
		$jufile ||= "aquota.user";
		$jgfile ||= "aquota.group";
		$options{"jqfmt"} = "vfsv0";
		}
	else {
		$jufile = "";
		$jgfile = "";
		delete($options{"jqfmt"});
		}
	if ($in{'ext2_quota'} == 1) { $options{$u} = $jufile; }
	elsif ($in{'ext2_quota'} == 2) { $options{$g} = $jgfile; }
	elsif ($in{'ext2_quota'} == 3) { $options{$u} = $jufile; $options{$g} = $jgfile; }
	}
elsif ($_[0] eq "fat" || $_[0] eq "vfat" ||
       $_[0] eq "msdos" || $_[0] eq "umsdos" || $_[0] eq "fatx") {
	# All dos-based filesystems have similar options
	delete($options{"uid"}); delete($options{"gid"});
	if ($in{fat_uid} ne "") { $options{"uid"} = getpwnam($in{'fat_uid'}); }
	if ($in{fat_gid} ne "") { $options{"gid"} = getgrnam($in{'fat_gid'}); }

	delete($options{"check"});
	if ($in{fat_check} ne "") { $options{"check"} = $in{fat_check}; }

	delete($options{"conv"});
	if ($in{fat_conv} ne "") { $options{"conv"} = $in{fat_conv}; }

	delete($options{"umask"});
	if (!$in{fat_umask_def}) {
		$in{fat_umask} =~ /^[0-7]{3}$/ ||
			&error(&text('linux_emask', $in{'fat_umask'}));
		$options{"umask"} = $in{fat_umask};
		}

	delete($options{"quiet"});
	if ($in{fat_quiet}) {
		$options{"quiet"} = "";
		}

	if ($_[0] eq "vfat") {
		# Parse extra vfat options..
		delete($options{"uni_xlate"});
		if ($in{fat_uni_xlate}) { $options{"uni_xlate"} = ""; }

		delete($options{"posix"});
		if ($in{fat_posix}) { $options{"posix"} = ""; }
		}
	}
elsif ($_[0] eq "hpfs") {
	# OS/2 filesystem options..
	delete($options{"uid"}); delete($options{"gid"});
	if ($in{hpfs_uid} ne "") { $options{"uid"} = getpwnam($in{hpfs_uid}); }
	if ($in{hpfs_gid} ne "") { $options{"gid"} = getgrnam($in{hpfs_gid}); }

	delete($options{"umask"});
	if (!$in{hpfs_umask_def}) {
		$in{hpfs_umask} =~ /^[0-7]{3}$/ ||
			&error(&text('linux_emask', $in{'hpfs_umask'}));
		$options{"umask"} = $in{hpfs_umask};
		}

	delete($options{"conv"});
	if ($in{hpfs_conv} ne "") { $options{"conv"} = $in{hpfs_conv}; }
	}
elsif ($_[0] eq "iso9660") {
	# Options for iso9660 cd-roms
	delete($options{"uid"}); delete($options{"gid"});
	if ($in{iso9660_uid} ne "")
		{ $options{"uid"} = getpwnam($in{iso9660_uid}); }
	if ($in{iso9660_gid} ne "")
		{ $options{"gid"} = getgrnam($in{iso9660_gid}); }

	delete($options{"norock"});
	if ($in{iso9660_norock}) { $options{"norock"} = ""; }

	delete($options{"mode"});
	$in{iso9660_mode} =~ /^[0-7]{3}$/ ||
		&error(&text('linux_emask', $in{'iso9660_mode'}));
	$options{"mode"} = $in{iso9660_mode};
	}
elsif ($_[0] eq "autofs") {
	# Options for automounter filesystems
	delete($options{'timeout'});
	if (!$in{'autofs_timeout_def'}) {
		$in{'autofs_timeout'} =~ /^\d+$/ ||
			&error(&text('linux_etimeout', $in{'autofs_timeout'}));
		$options{'timeout'} = $in{'autofs_timeout'};
		}
	delete($options{'pid-file'});
	if (!$in{'autofs_pid-file_def'}) {
		$in{'autofs_pid-file'} =~ /^\/\S+$/ ||
		       &error(&text('linux_epidfile', $in{'autofs_pid-file'}));
		$options{'pid-file'} = $in{'autofs_pid-file'};
		}
	}
elsif ($_[0] eq $smbfs_fs || $_[0] eq "cifs") {
	# Options for smb filesystems..
	local $support = $_[0] eq $smbfs_fs ? $smbfs_support : $cifs_support;
	delete($options{'user'}); delete($options{'username'});
	if ($in{smbfs_user}) {
		$options{$support == 4 ? 'username' : 'user'} = $in{smbfs_user};
		}

	delete($options{'passwd'}); delete($options{'password'});
	if ($in{smbfs_passwd}) {
		$options{$support == 4 ? 'password' : 'passwd'} = $in{smbfs_passwd};
		}

	if ($support == 4) {	
		delete($options{'credentials'});
		if ($in{smbfs_creds}) {
			$options{'credentials'} = $in{smbfs_creds};
			}
		}

	if ($support != 2) {
		delete($options{uid});
		if ($in{smbfs_uid} ne "") { $options{uid} = getpwnam($in{smbfs_uid}); }

		delete($options{gid});
		if ($in{smbfs_gid} ne "") { $options{gid} = getgrnam($in{smbfs_gid}); }
		}

	if ($support == 1) {
		delete($options{servername});
		if (!$in{smbfs_sname_def})
			{ $options{servername} = $in{smbfs_sname}; }
		}
	elsif ($support == 2 || $support == 4) {
		delete($options{workgroup});
		if (!$in{smbfs_wg_def})
			{ $options{workgroup} = $in{smbfs_wg}; }
		}

	if ($support < 3) {
		delete($options{clientname});
		if (!$in{smbfs_cname_def})
			{ $options{clientname} = $in{smbfs_cname}; }

		delete($options{machinename});
		if (!$in{smbfs_mname_def})
			{ $options{machinename} = $in{smbfs_mname}; }
		elsif (!&to_ipaddress($in{'smbfs_server'})) {
			# No hostname found for the server.. try to guess
			local($out, $sname);
			$sname = $in{'smbfs_server'};
			$out = &backquote_command("$config{'nmblookup_path'} -d 0 $sname 2>&1");
			if (!$? && $out =~ /^([0-9\.]+)\s+$sname\n/) {
				$options{machinename} = $1;
				}
			}
		}
	elsif ($support == 4) {
		delete($options{"netbiosname"});
		if (!$in{"smbfs_cname_def"}) {
			$in{"smbfs_cname"} =~ /^\S+$/ ||
				&error($text{'linux_ecname'});
			$options{"netbiosname"} = $in{"smbfs_cname"};
			}
		delete($options{"ip"});
		if (!$in{"smbfs_mname_def"}) {
			&to_ipaddress($in{"smbfs_mname"}) ||
				&error($text{'linux_emname'});
			$options{"ip"} = $in{"smbfs_mname"};
			}
		}

	if ($support == 1) {
		delete($options{fmode});
		if ($in{smbfs_fmode} !~ /^[0-7]{3}$/) {
			&error(&text('linux_efmode', $in{'smbfs_fmode'}));
			}
		elsif ($in{smbfs_fmode} ne "755")
			{ $options{fmode} = $in{smbfs_fmode}; }

		delete($options{dmode});
		if ($in{smbfs_dmode} !~ /^[0-7]{3}$/) {
			&error(&text('linux_edmode', $in{'smbfs_dmode'}));
			}
		elsif ($in{smbfs_dmode} ne "755")
			{ $options{dmode} = $in{smbfs_dmode}; }
		}
	elsif ($support >= 3) {
		if ($in{'smbfs_file_mode_def'}) {
			delete($options{'file_mode'});
			}
		else {
			$in{'smbfs_file_mode'} =~ /^0?[0-7]{3}$/ ||
			  &error(&text('linux_efmode', $in{'smbfs_file_mode'}));
			$options{'file_mode'} = $in{'smbfs_file_mode'};
			}

		if ($in{'smbfs_dir_mode_def'}) {
			delete($options{'dir_mode'});
			}
		else {
			$in{'smbfs_dir_mode'} =~ /^0?[0-7]{3}$/ ||
		    	  &error(&text('linux_edmode', $in{'smbfs_dir_mode'}));
			$options{'dir_mode'} = $in{'smbfs_dir_mode'};
			}

		delete($options{'ro'}); delete($options{'rw'});
		if ($in{'smbfs_ro'}) { $options{'ro'} = ''; }
		}
	if ($support == 4) {
		delete($options{'user'});
		if ($in{'smbfs_user2'}) { $options{'user'} = ''; }
		}

	if ($_[0] eq "cifs") {
		# Parse CIFS-specific options
		delete($options{'codepage'});
		if (!$in{'smbfs_codepage_def'}) {
			$in{'smbfs_codepage'} =~ /^\S+$/ ||
				&error($text{'linux_ecodepage'});
			$options{'codepage'} = $in{'smbfs_codepage'};
			}

		delete($options{'iocharset'});
		if (!$in{'smbfs_iocharset_def'}) {
			$in{'smbfs_iocharset'} =~ /^\S+$/ ||
				&error($text{'linux_eiocharset'});
			$options{'iocharset'} = $in{'smbfs_iocharset'};
			}

		delete($options{'nounix'});
		if ($in{'smbfs_nounix'}) { $options{'nounix'} = ''; }

		delete($options{'vers'});
		if (!$in{'smbfs_vers_def'}) {
			$in{'smbfs_vers'} =~ /^[0-9\.]+$/ ||
				&error($text{'linux_ecvers'});
			$options{'vers'} = $in{'smbfs_vers'};
			}
		}
	}
elsif ($_[0] eq "reiserfs") {
	# Save reiserfs options
	delete($options{'notail'});
	$options{'notail'} = "" if ($in{'lnx_notail'});

	if ($in{'lnx_user'} && !$in{'lnx_noexec'}) {
		# Have to force on the exec option
		$options{"exec"} = "";
		}
	}
elsif ($_[0] eq "tmpfs") {
	# Save tmpfs options
	if ($in{'lnx_tmpsize_def'}) {
		delete($options{'size'});
		}
	else {
		$in{'lnx_tmpsize'} =~ /^(\d+)([kmg]?)$/ ||
			&error($text{'lnx_etmpsize'});
		$options{'size'} = $in{'lnx_tmpsize'};
		}

	if ($in{'lnx_nr_blocks_def'}) {
		delete($options{'nr_blocks'});
		}
	else {
		$in{'lnx_nr_blocks'} =~ /^\d+$/ ||
			&error($text{'lnx_enr_blocks'});
		$options{'nr_blocks'} = $in{'lnx_nr_blocks'};
		}

	if ($in{'lnx_nr_inodes_def'}) {
		delete($options{'nr_inodes'});
		}
	else {
		$in{'lnx_nr_inodes'} =~ /^\d+$/ ||
			&error($text{'lnx_enr_inodes'});
		$options{'nr_inodes'} = $in{'lnx_nr_inodes'};
		}

	if ($in{'lnx_tmpmode_def'}) {
		delete($options{'mode'});
		}
	else {
		$in{'lnx_tmpmode'} =~ /^[0-7]{3,4}$/ ||
			&error($text{'lnx_etmpmode'});
		$options{'mode'} = $in{'lnx_tmpmode'};
		}
	}
elsif ($_[0] eq "xfs") {
	# Save XFS options
	delete($options{'quota'});
	delete($options{'usrquota'});
	delete($options{'uqnoenforce'});
	$options{'usrquota'} = "" if ($in{'xfs_usrquota'} == 1);
	$options{'uqnoenforce'} = "" if ($in{'xfs_usrquota'} == 2);

	delete($options{'grpquota'});
	delete($options{'gqnoenforce'});
	$options{'grpquota'} = "" if ($in{'xfs_grpquota'} == 1);
	$options{'gqnoenforce'} = "" if ($in{'xfs_grpquota'} == 2);
	}
elsif ($_[0] eq "ntfs") {
	# Save NTFS options
	delete($options{"uid"}); delete($options{"gid"});
	if ($in{ntfs_uid} ne "")
		{ $options{"uid"} = getpwnam($in{ntfs_uid}); }
	if ($in{ntfs_gid} ne "")
		{ $options{"gid"} = getgrnam($in{ntfs_gid}); }
	}
elsif ($_[0] eq "swap") {
	# Save SWAP options
	if ($in{'swap_pri_def'}) {
		delete($options{'pri'});
		}
	else {
		$in{'swap_pri'} =~ /^\d+$/ && $in{'swap_pri'} <= 32767 ||
			&error($text{'linux_eswappri'});
		$options{'pri'} = $in{'swap_pri'};
		}
	}

# Add loop option if mounting a normal file
if ($_[0] ne "swap" && $_[0] ne "auto" && $_[0] ne "autofs" &&
    $_[0] ne $smbfs_fs && $_[0] ne "cifs" && $_[0] ne "nfs" &&
    $_[0] ne "nfs4" && $_[0] ne "tmpfs") {
	local(@st);
	@st = stat($_[1]);
	if (@st && ($st[2] & 0xF000) == 0x8000) {
		# a regular file.. add the loop option
		if (!$options{'loop'}) {
			$options{'loop'} = "";
			}
		}
	}

# Return options string
foreach $k (sort { ($b eq "user" ? 1 : 0) <=> ($a eq "user" ? 1 : 0) } (keys %options)) {
	if ($options{$k} eq "") { push(@rv, $k); }
	else { push(@rv, "$k=$options{$k}"); }
	}
return @rv ? join(',' , @rv) : "-";
}


# Get the smbfs options from 'smbfs_opts' file in the current directory. This
# is sadly necessary because there is no way to get the current options for
# an existing smbfs mount... so webmin has to save them in a file when
# mounting. Blech.
sub read_smbopts
{
local($_);
open(SMBOPTS, "$module_config_directory/smbfs");
while(<SMBOPTS>) {
	/^(\S+)\s+(\S+)$/;
	$smbopts{$1} = $2;
	}
close(SMBOPTS);
}

sub write_smbopts
{
local($_);
&open_tempfile(SMBOPTS, "> $module_config_directory/smbfs");
foreach (keys %smbopts) {
	&print_tempfile(SMBOPTS, "$_\t$smbopts{$_}\n");
	}
&close_tempfile(SMBOPTS);
}


# create_swap(file, size, units)
# Calls dd and mkswap to setup a swap file
sub create_swap
{
local($out, $bl);
$bl = $_[1] * ($_[2] eq "t" ? 1024*1024*1024 :
	       $_[2] eq "g" ? 1024*1024 :
	       $_[2] eq "m" ? 1024 : 1);
$out = &backquote_logged("dd if=/dev/zero of=$_[0] bs=1024 count=$bl 2>&1");
if ($?) { return "dd failed : $out"; }
$out = &backquote_logged("mkswap $_[0] $bl 2>&1");
if ($?) { return "mkswap failed : $out"; }
&system_logged("sync >/dev/null 2>&1");
return 0;
}

# exports_list(host, dirarray, clientarray)
# Fills the directory and client array references with exports from some
# host. Returns an error string if something went wrong
sub exports_list
{
local($dref, $cref, $out, $_);
$dref = $_[1]; $cref = $_[2];
$out = &backquote_command("showmount -e ".quotemeta($_[0])." 2>&1", 1);
if ($?) { return $out; }

# Add '/' if the server is in NFSv4
if (nfs_max_version($_[0]) >= 4) {
    push(@$dref, "/"); push(@$cref, "*"); }

foreach (split(/\n/, $out)) {
	if (/^(\/\S*)\s+(.*)$/) {
		push(@$dref, $1); push(@$cref, $2);
		}
	}
return undef;
}

# nfs_max_version(host)
# Return the max NFS version allowed on a server
sub nfs_max_version
{
    local($_, $max, $out);
    $max = 0;
    $out = &backquote_command("/usr/sbin/rpcinfo -p ".quotemeta($_[0])." 2>&1", 1);
    if ($?) { return $out; }
    foreach (split(/\n/, $out)) {
	if ((/ +(\d) +.*nfs/) && ($1 > $max)) {
	    $max = $1; }
    }
    return $max;
}

# broadcast_addr()
# Returns a useable broadcast address for finding NFS servers
sub broadcast_addr
{
local($out);
$out = &backquote_command("ifconfig -a 2>&1", 1);
if ($out =~ /(eth|tr)\d\s+.*\n.*Bcast:(\S+)\s+/) { return $2; }
return "255.255.255.255";
}

# autofs_options(string)
# Converts a string of options line --timeout 60 to something like timeout=60
sub autofs_options
{
local(@options);
if ($_[0] =~ /--timeout\s+(\d+)/ || $_[0] =~ /-t\s+(\d+)/) {
	push(@options, "timeout=$1");
	}
if ($_[0] =~ /--pid-file\s+(\S+)/ || $_[0] =~ /-p\s+(\d+)/) {
	push(@options, "pid-file=$1");
	}
return join(',', @options);
}

# autofs_args(string)
# Convert a comma-separated options string into args for automount
sub autofs_args
{
local(%options, $args);
&parse_options("autofs", $_[0]);
if (defined($options{'timeout'})) {
	$args .= " --timeout $options{'timeout'}";
	}
if (defined($options{'pid-file'})) {
	$args .= " --pid-file $options{'pid-file'}";
	}
return $args;
}

# read_amd_conf()
# Returns the entire amd config file as a string
sub read_amd_conf
{
local $sl = $/;
$/ = undef;
local $rv;
foreach $f (split(/\s+/, $config{'auto_file'})) {
	open(AMD, $f);
	$rv .= <AMD>;
	close(AMD);
	}
$/ = $sl;
return $rv;
}

# write_amd_conf(text)
sub write_amd_conf
{
local @af = split(/\s+/, $config{'auto_file'});
&open_tempfile(AMD, ">$config{'auto_file'}");
&print_tempfile(AMD, $_[0]);
&close_tempfile(AMD);
}

# parse_amd_conf()
# Parses a new-style amd.conf file into a hashtable
sub parse_amd_conf
{
local (@rv, $str);
foreach $f (split(/\s+/, $config{'auto_file'})) {
	local $lnum = 0;
	open(AMD, $f);
	while(<AMD>) {
		s/\r|\n//g;
		s/#.*$//g;
		if (/\[\s*(\S+)\s*\]/) {
			$str = { 'dir' => $1,
				 'line' => $lnum,
				 'eline' => $lnum,
				 'file' => $f };
			push(@rv, $str);
			}
		elsif (/(\S+)\s*=\s*"(.*)"/ || /(\S+)\s*=\s*(\S+)/) {
			$str->{'opts'}->{$1} = $2;
			$str->{'eline'} = $lnum;
			}
		$lnum++;
		}
	close(AMD);
	}
return @rv;
}

# device_name(device, [non-local])
# Converts a device name to a human-readable form
sub device_name
{
# First try to get name from fdisk module, as it knowns better about IDE
# and SCSI devices
if (&foreign_check("fdisk") && !$_[1]) {
	&foreign_require("fdisk");
	my @disks = &fdisk::list_disks_partitions();
	foreach my $d (@disks) {
		if ($d->{'device'} eq $_[0]) {
			return $d->{'desc'};
			}
		foreach my $p (@{$d->{'parts'}}) {
			if ($p->{'device'} eq $_[0]) {
				return $p->{'desc'};
				}
			}
		}
	}

if (!$text{'select_part'}) {
	local %flang = &load_language('fdisk');
	foreach $k (keys %flang) {
		$text{$k} = $flang{$k} if ($k =~ /^select_/);
		}
	}
return $_[0] =~ /^\/dev\/(s|h|xv|v)d([a-z]+)(\d+)$/ ?
	&text('select_part', $1 eq 's' ? 'SCSI' : $1 eq 'xv' ? 'Xen' :
			     $1 eq 'v' ? 'VirtIO' : 'IDE',
			     uc($2), "$3") :
       $_[0] =~ /^\/dev\/(s|h|xv|v)d([a-z]+)$/ ?
	&text('select_device', $1 eq 's' ? 'SCSI' : $1 eq 'xv' ? 'Xen' :
			       $1 eq 'v' ? 'VirtIO' : 'IDE',
			       uc($2)) :
       $_[0] =~ /^\/dev\/mmcblk(\d+)p(\d+)$/ ?
	&text('select_part', "SD-Card", "$1", "$2") :
       $_[0] =~ /^\/dev\/mmcblk(\d+)$/ ?
	&text('select_device', "SD-Card", "$1") :
       $_[0] =~ /rd\/c(\d+)d(\d+)p(\d+)$/ ?
	&text('select_mpart', "$1", "$2", "$3") :
       $_[0] =~ /ida\/c(\d+)d(\d+)p(\d+)$/ ?
	&text('select_cpart', "$1", "$2", "$3") :
       $_[0] =~ /cciss\/c(\d+)d(\d+)p(\d+)$/ ?
	&text('select_smartpart', "$1", "$2", "$3") :
       $_[0] =~ /scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/part(\d+)/ ?
	&text('select_spart', "$1", "$2", "$3", "$4", "$5") :
       $_[0] =~ /scsi\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
	&text('select_scsi', "$1", "$2", "$3", "$4") :
       $_[0] =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/part(\d+)/ ?
	&text('select_snewide', "$1", "$2", "$3", "$4", "$5") :
       $_[0] =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/disc/ ?
	&text('select_newide', "$1", "$2", "$3", "$4") :
       $_[0] =~ /ataraid\/disc(\d+)\/part(\d+)$/ ?
	&text('select_ppart', "$1", "$2") :
       $_[0] =~ /fd(\d+)$/ ?
	&text('select_fd', "$1") :
       $_[0] =~ /md(\d+)$/ ?
	&text('linux_rdev', "$1") :
       $_[0] =~ /\/dev\/([^\/]+)\/([^\/]+)$/ && $1 ne "cdroms" ?
	&text('linux_ldev', "$1", "$2") :
       $_[0] =~ /LABEL=(\S+)/i ?
	&text('linux_label', "$1") :
       $_[0] =~ /UUID=(\S+)/i ?
	&text('linux_uuid', "$1") :
       $_[0] eq '/dev/cdrom' ?
	$text{'linux_cddev'} :
       $_[0] eq '/dev/burner' ?
	$text{'linux_burnerdev'} :
       $_[0] =~ /cdroms\/cdrom(\d+)$/ ?
	&text('linux_cddev2', "$1") :
	$_[0];
}

sub files_to_lock
{
return ( $config{'fstab_file'}, $config{'autofs_file'},
	 split(/\s+/, $config{'auto_file'}) );
}

# lowercase_share_path(path)
# Converts a share spec like //FOO/BAR/Smeg to //foo/bar/Smeg
sub lowercase_share_path
{
local ($path) = @_;
$path =~ s/\//\\/g;
if ($path =~ /^\\\\([^\\]+)\\([^\\]+)(\\.*)?/) {
	$path = "\\\\".lc($1)."\\".lc($2).$3;
	}
return $path;
}

1;

