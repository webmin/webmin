# solaris-lib.pl
# Filesystem functions for Solaris (works for me on 2.5)

$smbmount = &has_command("rumba") ? "rumba" :
	    &has_command("shlight") ? "shlight" : undef;

# Return information about a filesystem, in the form:
#  directory, device, type, options, fsck_order, mount_at_boot
# If a field is unused or ignored, a - appears instead of the value.
# Swap-filesystems (devices or files mounted for VM) have a type of 'swap',
# and 'swap' in the directory field
sub list_mounts
{
return @list_mounts_cache if (@list_mounts_cache);
local(@rv, @p, $_, $i); $i = 0;

# List normal filesystem mounts
open(FSTAB, $config{fstab_file});
while(<FSTAB>) {
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[3] eq "swap") { $p[2] = "swap"; }
	if ($p[3] eq "proc") { $p[0] = "proc"; }
	$rv[$i++] = [ $p[2], $p[0], $p[3], $p[6], $p[4], $p[5] ];
	}
close(FSTAB);

# List automount points
open(AUTOTAB, $config{autofs_file});
while(<AUTOTAB>) {
	chop; s/#.*$//g;
	if (!/\S/ || /^[+\-]/) { next; }
	@p = split(/\s+/, $_);
	if ($p[2] eq "") { $p[2] = "-"; }
	else { $p[2] =~ s/^-//g; }
	$rv[$i++] = [ $p[0], $p[1], "autofs", $p[2], "-", "yes" ];
	}
close(AUTOTAB);

@list_mounts_cache = @rv;
return @rv;
}


# create_mount(directory, device, type, options, fsck_order, mount_at_boot)
# Add a new entry to the fstab file, and return the index of the new entry
sub create_mount
{
local($len, @mlist, $fcsk, $dir);
if ($_[2] eq "autofs") {
	# An autofs mount.. add to /etc/auto_master
	$len = grep { $_->[2] eq "autofs" } (&list_mounts());
	&open_tempfile(AUTOTAB, ">> $config{autofs_file}");
	&print_tempfile(AUTOTAB, "$_[0] $_[1]",($_[3] eq "-" ? "" : " -$_[3]"),"\n");
	&close_tempfile(AUTOTAB);
	}
else {
	# Add to the fstab file
	$len = grep { $_->[2] ne "autofs" } (&list_mounts());
	&open_tempfile(FSTAB, ">> $config{fstab_file}");
	if ($_[2] eq "ufs" || $_[2] eq "s5fs") {
		($fsck = $_[1]) =~ s/\/dsk\//\/rdsk\//g;
		}
	else { $fsck = "-"; }
	if ($_[2] eq "swap") { $dir = "-"; }
	else { $dir = $_[0]; }
	&print_tempfile(FSTAB, "$_[1]  $fsck  $dir  $_[2]  $_[4]  $_[5]  $_[3]\n");
	&close_tempfile(FSTAB);
	}
undef(@list_mounts_cache);
return $len;
}


# delete_mount(index)
# Delete some mount from the table
sub delete_mount
{
local(@fstab, $i, $line, $_);
open(FSTAB, $config{fstab_file});
@fstab = <FSTAB>;
close(FSTAB);
$i = 0;

&open_tempfile(FSTAB, "> $config{fstab_file}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $i++ == $_[0]) {
		# found the line not to include
		}
	else { &print_tempfile(FSTAB, $_,"\n"); }
	}
&close_tempfile(FSTAB);

open(AUTOTAB, $config{autofs_file});
@autotab = <AUTOTAB>;
close(AUTOTAB);
&open_tempfile(AUTOTAB, "> $config{autofs_file}");
foreach (@autotab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $line !~ /^[+\-]/ && $i++ == $_[0]) {
		# found line not to include..
		}
	else { &print_tempfile(AUTOTAB, $_,"\n"); }
	}
&close_tempfile(AUTOTAB);
undef(@list_mounts_cache);
}


# change_mount(num, directory, device, type, options, fsck_order, mount_at_boot)
# Change an existing permanent mount
sub change_mount
{
local(@fstab, @autotab, $i, $line, $fsck, $dir, $_);
$i = 0;

open(FSTAB, $config{fstab_file});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, "> $config{fstab_file}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $i++ == $_[0]) {
		# Found the line to replace
		if ($_[3] eq "ufs" || $_[3] eq "s5fs") {
			($fsck = $_[2]) =~ s/\/dsk\//\/rdsk\//g;
			}
		else { $fsck = "-"; }
		if ($_[3] eq "swap") { $dir = "-"; }
		else { $dir = $_[1]; }
		&print_tempfile(FSTAB, "$_[2]  $fsck  $dir  $_[3]  $_[5]  $_[6]  $_[4]\n");
		}
	else { &print_tempfile(FSTAB, $_,"\n"); }
	}
&close_tempfile(FSTAB);

open(AUTOTAB, $config{autofs_file});
@autotab = <AUTOTAB>;
close(AUTOTAB);
&open_tempfile(AUTOTAB, "> $config{autofs_file}");
foreach (@autotab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $line !~ /^[+\-]/ && $i++ == $_[0]) {
		# Found the line to replace
		&print_tempfile(AUTOTAB, "$_[1]  $_[2]  ",
				($_[4] eq "-" ? "" : "-$_[4]"),"\n");
		}
	else { &print_tempfile(AUTOTAB, $_,"\n"); }
	}
&close_tempfile(AUTOTAB);
undef(@list_mounts_cache);
}


# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
# For swap files, the directory will be 'swap'
sub list_mounted
{
return @list_mounted_cache if (@list_mounted_cache);
local(@rv, @p, $_, $i, $r);
&open_execute_command(SWAP, "swap -l 2>/dev/null", 1, 1);
while(<SWAP>) {
	if (/^(\/\S+)\s+/) { push(@rv, [ "swap", $1, "swap", "-" ]); }
	}
close(SWAP);
&open_tempfile(MNTTAB, "/etc/mnttab");
while(<MNTTAB>) {
	s/#.*$//g; if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[0] =~ /:vold/) { next; }
	if ($p[0] =~ /^(rumba|shlight)-(\d+)$/) {
		# rumba smb mount
		local($args, $ps); $p[3] = "pid=$2";
		$ps = (-x "/usr/ucb/ps") ? "/usr/ucb/ps auwwwwx $2"
				 	 : "ps -o args -f $2";
		&backquote_command($ps, 1) =~ /(rumba|shlight)\s+\/\/([^\/]+)\/(.*\S)\s+(\/\S+)(.*)/ || next;
		$serv = $2; $shar = $3; $p[2] = "rumba"; $args = $5;
		if ($args =~ /\s+-s\s+(\S+)/ && $1 ne $serv) {
			$p[0] = "\\\\$1\\$shar";
			$p[3] .= ",machinename=$serv";
			}
		else { $p[0] = "\\\\$serv\\$shar"; }
		if ($args =~ /\s+-c\s+(\S+)/) { $p[3] .= ",clientname=$1"; }
		if ($args =~ /\s+-U\s+(\S+)/) { $p[3] .= ",username=$1"; }
		if ($args =~ /\s+-u\s+(\S+)/) { $p[3] .= ",uid=$1"; }
		if ($args =~ /\s+-g\s+(\S+)/) { $p[3] .= ",gid=$1"; }
		if ($args =~ /\s+-f\s+(\S+)/) { $p[3] .= ",fmode=$1"; }
		if ($args =~ /\s+-d\s+(\S+)/) { $p[3] .= ",dmode=$1"; }
		if ($args =~ /\s+-C/) { $p[3] .= ",noupper"; }
		if ($args =~ /\s+-P\s+(\S+)/) { $p[3] .= ",password=$1"; }
		if ($args =~ /\s+-S/) { $p[3] .= ",readwrite"; }
		if ($args =~ /\s+-w/) { $p[3] .= ",readonly"; }
		if ($args =~ /\s+-e/) { $p[3] .= ",attr"; }
		}
	else { $p[3] = join(',' , (grep {!/^dev=/} split(/,/ , $p[3]))); }
	push(@rv, [ $p[1], $p[0], $p[2], $p[3] ]);
	}
&close_tempfile(MNTTAB);
foreach $r (@rv) {
	if ($r->[2] eq "cachefs" && $r->[1] =~ /\.cfs_mnt_points/) {
		# Oh no.. a caching filesystem mount. Fiddle things so that
		# it looks right.
		for($i=0; $i<@rv; $i++) {
			if ($rv[$i]->[0] eq $r->[1]) {
				# Found the automatically mounted entry. lose it
				$r->[1] = $rv[$i]->[1];
				splice(@rv, $i, 1);
				last;
				}
			}
		}
	}
@list_mounted_cache = @rv;
return @rv;
}


# mount_dir(directory, device, type, options)
# Mount a new directory from some device, with some options. Returns 0 if ok,
# or an error string if failed. If the directory is 'swap', then mount as
# virtual memory.
sub mount_dir
{
local($out, $opts);
if ($_[0] eq "swap") {
	# Adding a swap device
	$out = &backquote_logged("swap -a $_[1] 2>&1");
	if ($?) { return $out; }
	}
else {
	# Mounting a directory
	if ($_[2] eq "cachefs") {
		# Mounting a caching filesystem.. need to create cache first
		local(%options);
		&parse_options("cachefs", $_[3]);
		if (!(-r "$options{cachedir}/.cfs_resource")) {
			# The cache directory does not exist.. set it up
			if (-d $options{cachedir} &&
			    !rmdir($options{"cachedir"})) {
				return &text('solaris_ecacheexists',
					     $options{'cachedir'});
				}
			$out = &backquote_logged("cfsadmin -c $options{cachedir} 2>&1");
			if ($?) { return $out; }
			}
		}
	if ($_[2] eq "rumba") {
		# call 'rumba' to mount
		local(%options, $shortname, $shar, $opts, $rv);
		&parse_options("rumba", $_[3]);
		$shortname = &get_system_hostname();
		if ($shortname =~ /^([^\.]+)\.(.+)$/) { $shortname = $1; }
		$_[1] =~ /^\\\\(.+)\\(.+)$/;
		$shar = "//".($options{machinename} ?$options{machinename} :$1).
			"/$2";
		$opts = ("-s $1 ").
		 (defined($options{'clientname'}) ?
			"-c $options{'clientname'} " : "-c $shortname ").
		 (defined($options{'username'}) ?
			"-U $options{'username'} " : "").
		 (defined($options{'uid'}) ? "-u $options{'uid'} " : "").
		 (defined($options{'gid'}) ? "-g $options{'gid'} " : "").
		 (defined($options{'fmode'}) ? "-f $options{'fmode'} " : "").
		 (defined($options{'dmode'}) ? "-d $options{'dmode'} " : "").
		 (defined($options{'noupper'}) ? "-C " : "").
		 (defined($options{'password'}) ?
			"-P $options{'password'} " : "-n ").
		 (defined($options{'readwrite'}) ? "-S " : "").
		 (defined($options{'readonly'}) ? "-w " : "").
		 (defined($options{'attr'}) ? "-e " : "");
		local $rtemp = &transname();
		$rv = &system_logged("rumba \"$shar\" $_[0] $opts >$rtemp 2>&1 </dev/null");
		$out = `cat $rtemp`; unlink($rtemp);
		if ($rv) { return "<pre>$out</pre> : rumba \"$shar\" $_[0] $opts"; }
		}
	else {
		$opts = $_[3] eq "-" ? "" : "-o \"$_[3]\"";
		$out = &backquote_logged("mount -F $_[2] $opts -- $_[1] $_[0] 2>&1");
		if ($?) { return $out; }
		}
	}
undef(@list_mounted_cache);
return 0;
}


# unmount_dir(directory, device, type)
# Unmount a directory (or swap device) that is currently mounted. Returns 0 if
# ok, or an error string if failed
sub unmount_dir
{
if ($_[0] eq "swap") {
	$out = &backquote_logged("swap -d $_[1] 2>&1");
	}
elsif ($_[2] eq "rumba") {
	# kill the process (if nobody is in the directory)
	$dir = $_[0];
	if (&backquote_command("fuser -c $_[0] 2>/dev/null", 1) =~ /\d/) {
		return &text('solaris_ebusy', $_[0]);
		}
	if (&backquote_command("cat /etc/mnttab", 1) =~
	    /(rumba|shlight)-(\d+)\s+$dir\s+nfs/) {
		&kill_logged('TERM', $2) || return $text{'solaris_ekill'};
		}
	else {
		return $text{'solaris_epid'};
		}
	sleep(1);
	}
else {
	$out = &backquote_logged("umount $_[0] 2>&1");
	}
undef(@list_mounted_cache);
if ($?) { return $out; }
return 0;
}


# disk_space(type, directory)
# Returns the amount of total and free space for some filesystem, or an
# empty array if not appropriate.
sub disk_space
{
if (&get_mounted($_[1], "*") < 0) { return (); }
if ($_[0] eq "fd" || $_[0] eq "proc" || $_[0] eq "swap" || $_[0] eq "autofs") {
	return ();
	}
if (&backquote_command("df -k ".quotemeta($_[1]), 1) =~
    /Mounted on\n\S+\s+(\S+)\s+(\S+)\s+(\S+)/) {
	if ($1 == 0) {
		# Size is sometimes zero on Solaris? Fake it..
		return ($2+$3, $3);
		}
	else {
		return ($1, $3);
		}
	}
return ( );
}


# list_fstypes()
# Returns an array of all the supported filesystem types. If a filesystem is
# found that is not one of the supported types, generate_location() and
# generate_options() will not be called for it.
sub list_fstypes
{
local @fs = ("ufs", "nfs", "hsfs", "pcfs", "lofs", "cachefs",
	     "swap", "tmpfs", "autofs");
if (&running_in_zone()) {
	# Only the filesystems are available in zones
	@fs = ( "tmpfs", "autofs", "nfs" );
	}
push(@fs, $smbmount) if ($smbmount);
push(@fs, "udfs") if ($gconfig{'os_version'} >= 8);
push(@fs, "xmemfs") if ($gconfig{'os_version'} >= 8 &&
			$gconfig{'os_version'} <= 10);
return @fs;
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ufs","Solaris Unix Filesystem",
	  "nfs","Network Filesystem",
	  "hsfs","ISO9660 CD-ROM",
	  "pcfs","MS-DOS Filesystem",
	  "lofs","Loopback Filesystem",
	  "cachefs","Caching Filesystem",
	  "swap","Virtual Memory",
	  "tmpfs","RAM Disk",
	  "xmemfs","Large RAM Disk",
	  "autofs","Automounter Filesystem",
	  "proc","Process Image Filesystem",
	  "fd","File Descriptor Filesystem",
	  "mntfs","Filesystems List",
	  "udfs","DVD Filesystem",
	  "rumba","Windows Networking Filesystem");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# mount_modes(type)
# Given a filesystem type, returns 4 numbers that determine how the file
# system can be mounted, and whether it can be fsck'd
sub mount_modes
{
if ($_[0] eq "ufs" || $_[0] eq "cachefs" || $_[0] eq "s5fs") {
	return (2, 1, 1, 0);
	}
elsif ($_[0] eq "rumba") { return (0, 1, 0, 0); }
else { return (2, 1, 0, 0); }
}


# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return ($_[0] eq "nfs" || $_[0] eq "tmpfs" || $_[0] eq "cachefs" ||
        $_[0] eq "autofs" || $_[0] eq "lofs" || $_[0] eq "rumba" || $_[0] eq "xmemfs");
}


# generate_location(type, location)
# Output HTML for editing the mount location of some filesystem.
sub generate_location
{
local ($type, $loc) = @_;
if ($type eq "nfs") {
	# NFS mount from some host and directory
	local ($nfsmode, $nfshost, $nfspath);
	if ($loc =~ /^nfs:/) { $nfsmode = 2; }
	elsif (!$loc) {
		$nfsmode = 0;
		}
	elsif ($loc =~ /^([A-z0-9\-\.]+):([^,]+)$/) {
		$nfsmode = 0; $nfshost = $1; $nfspath = $2;
		}
	else { $nfsmode = 1; }
	if ($gconfig{'os_version'} >= 2.6) {
		# Solaris 2.6 can list multiple NFS servers in mount
		local @opts;
		push(@opts, [ 0, $text{'solaris_nhost'},
			&ui_textbox("nfs_host", $nfshost, 30).
			&nfs_server_chooser_button("nfs_host").
			"&nbsp;".
			"<b>".$text{'solaris_ndir'}."</b> ".
			&ui_textbox("nfs_dir", $nfspath, 30).
			&nfs_export_chooser_button("nfs_host", "nfs_dir") ]);

		push(@opts, [ 1, $text{'solaris_nmult'},
			&ui_textbox("nfs_list",
				    $nfsmode == 1 ? $loc : "", 40) ]);

		if ($gconfig{'os_version'} >= 7) {
			push(@opts, [ 2, $text{'solaris_webnfs'},
				&ui_textbox("nfs_url",
					    $nfsmode == 2 ? $loc : "", 40) ]);
			}
		print &ui_table_row($text{'solaris_nsource'},
			&ui_radio_table("nfs_serv", $nfsmode, \@opts));
		}
	else {
		print &ui_table_row($text{'solaris_nhost'},
			&ui_textbox("nfs_host", $nfshost, 30).
			&nfs_server_chooser_button("nfs_host").
			"&nbsp;".
			"<b>".$text{'solaris_ndir'}."</b> ".
			&ui_textbox("nfs_dir", $nfspath, 30).
			&nfs_export_chooser_button("nfs_host", "nfs_dir"));
		}
	}
elsif ($type eq "tmpfs" || $type eq "xmemfs") {
	# Location is irrelevant for tmpfs and xmemfs filesystems
	}
elsif ($type eq "ufs") {
	# Mounted from a normal disk, raid (MD) device or from
	# somewhere else
	&foreign_require("format");
	local ($ufs_dev, $ufs_md);
	if ($_[1] =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/ ||
	    $_[1] =~ /^\/dev\/dsk\/c([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$ufs_dev = 0;
		}
	elsif ($_[1] eq "") {
		$ufs_dev = 0;
		}
	elsif ($_[1] =~ /^\/dev\/md\/dsk\/d([0-9]+)$/) {
		$ufs_dev = 1;
		$ufs_md = $1;
		}
	else {
		$ufs_dev = 2;
		}
	local @opts;

	# Regular disk
	local $found;
	local $sel = &format::partition_select("ufs_disk", $_[1], 0,
					       $ufs_dev ? \$found : undef);
	push(@opts, [ 0, $text{'solaris_scsi'}, $sel ]);


	# RAID device
	push(@opts, [ 1, $text{'solaris_raid'},
		      $text{'solaris_unit'}." ".
		      &ui_textbox("ufs_md", $ufs_md, 5) ]);

	# Something else
	push(@opts, [ 2, $text{'solaris_otherdev'},
		      &ui_textbox("ufs_path", $ufs_dev == 2 ? $loc : "", 40) ]);
	print &ui_table_row($text{'solaris_ufs'},
		&ui_radio_table("ufs_dev", $ufs_dev, \@opts));
	}
elsif ($type eq "swap") {
	# Swapping to a disk partition or a file
	&foreign_require("format");
	local ($swap_dev);
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/ ||
	    $loc =~ /^\/dev\/dsk\/c([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$swap_dev = 0;
		}
	elsif ($loc eq "") {
		$swap_dev = 0;
		}
	else {
		$swap_dev = 1;
		}
	local @opts;

	# Regular disk
	local $found;
	local $sel = &format::partition_select("swap_disk", $_[1], 0,
					       $swap_dev ? \$found : undef);
	push(@opts, [ 0, $text{'solaris_scsi'}, $sel ]);

	# Other path
	push(@opts, [ 1, $text{'solaris_file'},
		      &ui_textbox("swap_path", $swap_dev == 1 ? $loc : "", 40)
		    ]);
	print &ui_table_row($text{'solaris_swapfile'},
		&ui_radio_table("swap_dev", $swap_dev, \@opts));
	}
elsif ($type eq "hsfs" || $type eq "udfs") {
	# Mounting a SCSI cdrom or DVD
	local ($hsfs_dev, $scsi_c, $scsi_t, $scsi_d, $scsi_s, $scsi_path);
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$hsfs_dev = 0;
		$scsi_c = $1; $scsi_t = $2; $scsi_d = $3; $scsi_s = $4;
		}
	elsif ($loc eq "") {
		$hsfs_dev = 0;
		$scsi_c = 0; $scsi_t = 6; $scsi_d = 0; $scsi_s = 0;
		}
	else {
		$hsfs_dev = 2; $scsi_path = $_[1];
		}
	local @opts;
	push(@opts, [ 0, $text{'solaris_scsi'},
		      $text{'solaris_ctrlr'}." ".
		        &ui_textbox("ufs_c", $scsi_c, 4)." ".
		      $text{'solaris_target'}.
		        &ui_textbox("ufs_t", $scsi_t, 4)." ".
		      $text{'solaris_unit'}.
		        &ui_textbox("ufs_d", $scsi_d, 4)." ".
		      $text{'solaris_part'}.
		        &ui_textbox("ufs_s", $scsi_s, 4) ]);
	push(@opts, [ 2, $text{'solaris_otherdev'},
		      &ui_textbox("ufs_path", $scsi_path, 40) ]);
	print &ui_table_row($type eq "hsfs" ? $text{'solaris_cdrom'}
					    : $text{'solaris_dvd'},
		&ui_radio_table("ufs_dev", $hsfs_dev, \@opts));
	}
elsif ($type eq "pcfs") {
	# Mounting a SCSI msdos filesystem
	local ($pcfs_dev);
	&foreign_require("format");
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/ ||
	    $loc =~ /^\/dev\/dsk\/c([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$pcfs_dev = 0;
		}
	elsif ($_[1] eq "") {
		$pcfs_dev = 0;
		}
	else {
		$pcfs_dev = 2;
		}
	local @opts;

	local $found;
	local $sel = &format::partition_select("ufs_disk", $_[1], 0,
					       $pcfs_dev ? \$found : undef);
	push(@opts, [ 0, $text{'solaris_scsi'}, $sel ]);

	push(@opts, [ 2, $text{'solaris_file'},
		      &ui_textbox("ufs_path", $pcfs_dev == 2 ? $loc : "", 40)]);
	print &ui_table_row($text{'solaris_msdos'},
		&ui_radio_table("ufs_dev", $pcfs_dev, \@opts));
	}
elsif ($type eq "lofs") {
	# Mounting some directory to another location
	print &ui_table_row($text{'solaris_orig'},
		&ui_textbox("lofs_src", 40, $loc)." ".
		&file_chooser_button("lofs_src", 1));
	}
elsif ($type eq "cachefs") {
	# Mounting a cached filesystem of some type.. need a location for
	# the source of the mount
	print &ui_table_row($text{'solaris_cache'},
		&ui_textbox("cfs_src", 40, $loc));
	}
elsif ($type eq "autofs") {
	# An automounter entry.. can be -hosts, -xfn or from some mapping
	local $mode = $loc eq "-hosts" ? 1 :
		      $loc eq "-xfn" ? 2 : 0;
	print &ui_table_row($text{'solaris_automap'},
	    &ui_radio_table("autofs_type", $mode,
		[ [ 0, $text{'linux_map'},
		    &ui_textbox("autofs_map", 30, $mode == 0 ? $loc : "") ],
		  [ 1, $text{'solaris_autohosts'} ],
		  [ 2, $text{'solaris_autoxfn'} ] ]));
	}
elsif ($type eq "rumba") {
	# Windows filesystem
	local ($server, $share) = $loc =~ /^\\\\([^\\]*)\\(.*)$/ ?
					($1, $2) : ( );
	print &ui_table_row($text{'solaris_server'},
		&ui_textbox("rumba_server", $server, 30)." ".
		&smb_server_chooser_button("rumba_server")." ".
		"&nbsp;".
		"<b>$text{'solaris_share'}</b> ".
		&ui_textbox("rumba_share", $share, 30)." ".
		&smb_share_chooser_button("rumba_server", "rumba_share"));
	}
}


# generate_options(type, newmount)
# Output HTML for editing mount options for a partilcar filesystem 
# under this OS
sub generate_options
{
if ($_[0] eq "nfs") {
	# Solaris NFS has many options, not all of which are editable here
	print "<tr> <td><b>$text{'solaris_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=nfs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=nfs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_grpid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_grpid value=0 %s> $text{'yes'}\n",
		defined($options{"grpid"}) ? "" : "checked";
	printf "<input type=radio name=nfs_grpid value=1 %s> $text{'no'}</td>\n",
		defined($options{"grpid"}) ? "checked" : "";

	print "<td><b>$text{'solaris_soft'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_soft value=1 %s> $text{'yes'}\n",
		defined($options{"soft"}) ? "checked" : "";
	printf "<input type=radio name=nfs_soft value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"soft"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_bg'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_bg value=1 %s> $text{'yes'}\n",
		defined($options{"bg"}) ? "checked" : "";
	printf "<input type=radio name=nfs_bg value=0 %s> $text{'no'}</td>\n",
		defined($options{"bg"}) ? "" : "checked";

	print "<td><b>$text{'solaris_quota'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_quota value=1 %s> $text{'yes'}\n",
		defined($options{"quota"}) ? "checked" : "";
	printf "<input type=radio name=nfs_quota value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"quota"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_nointr'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nointr value=0 %s> $text{'yes'}\n",
		defined($options{"nointr"}) ? "" : "checked";
	printf "<input type=radio name=nfs_nointr value=1 %s> $text{'no'}</td>\n",
		defined($options{"nointr"}) ? "checked" : "";

	print "<td><b>$text{'solaris_nfsver'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_vers_def value=1 %s> $text{'solaris_highest'}\n",
		defined($options{"vers"}) ? "" : "checked";
	printf "<input type=radio name=nfs_vers_def value=0 %s>\n",
		defined($options{"vers"}) ? "checked" : "";
	print "<input size=2 name=nfs_vers value=$options{vers}></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_proto'}</b></td>\n";
	print "<td nowrap><select name=proto>\n";
	printf "<option value=\"\" %s>$text{'default'}</option>\n",
		defined($options{"proto"}) ? "" : "selected";
	&open_tempfile(NETCONFIG, "/etc/netconfig");
	while(<NETCONFIG>) {
		if (!/^([A-z0-9\_\-]+)\s/) { next; }
		printf "<option value=\"$1\" %s>$1</option>\n",
			$options{"proto"} eq $1 ? "selected" : "";
		}
	&close_tempfile(NETCONFIG);
	print "</select></td>\n";

	print "<td><b>$text{'solaris_port'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_port_def value=1 %s> $text{'default'}\n",
		defined($options{"port"}) ? "" : "checked";
	printf "<input type=radio name=nfs_port_def value=0 %s>\n",
		defined($options{"port"}) ? "checked" : "";
	print "<input size=5 name=nfs_port value=$options{port}></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_timeo'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_timeo_def value=1 %s> $text{'default'}\n",
		defined($options{"timeo"}) ? "" : "checked";
	printf "<input type=radio name=nfs_timeo_def value=0 %s>\n",
		defined($options{"timeo"}) ? "checked" : "";
	printf "<input size=5 name=nfs_timeo value=$options{timeo}></td>\n";

	print "<td><b>$text{'solaris_retrans'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_retrans_def value=1 %s> $text{'default'}\n",
		defined($options{"retrans"}) ? "" : "checked";
	printf "<input type=radio name=nfs_retrans_def value=0 %s>\n",
		defined($options{"retrans"}) ? "checked" : "";
	print "<input size=5 name=nfs_retrans value=$options{retrans}></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_auth'}</b></td>\n";
	$nfs_auth = $options{'sec'} ? $options{'sec'} :
		    defined($options{"secure"}) ? "dh" :
		    defined($options{"kerberos"}) ? "krb" : "";
	print "<td><select name=nfs_auth>\n";
	printf "<option value=\"\" %s>$text{'solaris_none'}</option>\n",
		$nfs_auth eq "" ? "selected" : "";
	printf "<option value=dh %s>$text{'solaris_des'}</option>\n",
		$nfs_auth eq "dh" ? "selected" : "";
	printf "<option value=krb %s>$text{'solaris_krb'}</option>\n",
		$nfs_auth eq "krb" ? "selected" : "";
	print "</select></td>\n";

	if ($gconfig{'os_version'} >= 7) {
		print "<td><b>$text{'solaris_public'}</b></td> <td>\n";
		printf "<input type=radio name=nfs_public value=1 %s> $text{'yes'}\n",
			defined($options{'public'}) ? "checked" : "";
		printf "<input type=radio name=nfs_public value=0 %s> $text{'no'}\n",
			defined($options{'public'}) ? "" : "checked";
		print "</td>\n";
		}
	print "</tr>\n";
	}
if ($_[0] eq "ufs") {
	# Solaris UFS also has many options, not all of which are here
	print "<tr> <td><b>$text{'solaris_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=ufs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=ufs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_nointr'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_nointr value=0 %s> $text{'yes'}\n",
		defined($options{"nointr"}) ? "" : "checked";
	printf "<input type=radio name=ufs_nointr value=1 %s> $text{'no'}</td>\n",
		defined($options{"nointr"}) ? "checked" : "";

	print "<td><b>$text{'solaris_quotab'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_quota value=1 %s> $text{'yes'}\n",
		defined($options{"quota"}) || defined($options{"rq"}) ?
			"checked" : "";
	printf "<input type=radio name=ufs_quota value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"quota"}) || defined($options{"rq"}) ?
			"" : "checked";

	print "<tr> <td><b>$text{'solaris_onerror'}</b></td>\n";
	print "<td><select name=ufs_onerror>\n";
	foreach ('panic', 'lock', 'umount', 'repair') {
		next if ($_ eq "repair" && $gconfig{'os_version'} >= 10);
		printf "<option value=\"$_\" %s>$_</option>\n",
		 $options{onerror} eq $_ ||
		 !defined($options{onerror}) && $_ eq "panic" ? "selected" : "";
		}
	print "</select></td>\n";

	if ($gconfig{'os_version'} >= 7) {
		print "<td><b>$text{'solaris_noatime'}</b></td> <td>\n";
		if ($gconfig{'os_version'} >= 8) {
			printf "<input type=radio name=ufs_noatime value=0 %s> $text{'solaris_immed'}\n",
				defined($options{'nodfratime'}) ? "checked" : "";
			printf "<input type=radio name=ufs_noatime value=1 %s> $text{'solaris_defer'}\n",
				!defined($options{'nodfratime'}) &&
				!defined($options{'noatime'}) ? "checked" : "";
			printf "<input type=radio name=ufs_noatime value=2 %s> $text{'no'}</td> </tr>\n",
				defined($options{'noatime'}) ? "checked" : "";
			}
		else {
			printf "<input type=radio name=ufs_noatime value=0 %s> $text{'yes'}\n",
				defined($options{'noatime'}) ? "" : "checked";
			printf "<input type=radio name=ufs_noatime value=1 %s> $text{'no'}</td> </tr>\n",
				defined($options{'noatime'}) ? "checked" : "";
			}

		print "<tr> <td><b>$text{'solaris_force'}</b></td> <td>\n";
		printf "<input type=radio name=ufs_force value=1 %s> $text{'yes'}\n",
			defined($options{'forcedirectio'}) ? "checked" : "";
		printf "<input type=radio name=ufs_force value=0 %s> $text{'no'}</td>\n",
			defined($options{'forcedirectio'}) ? "" : "checked";

		print "<td><b>$text{'solaris_nolarge'}</td> <td>\n";
		printf "<input type=radio name=ufs_nolarge value=0 %s> $text{'yes'}\n",
			defined($options{'nolargefiles'}) ? "" : "checked";
		printf "<input type=radio name=ufs_nolarge value=1 %s> $text{'no'}</td> </tr>\n",
			defined($options{'nolargefiles'}) ? "checked" : "";

		print "<tr> <td><b>$text{'solaris_logging'}</td> <td>\n";
		printf "<input type=radio name=ufs_logging value=1 %s> $text{'yes'}\n",
			defined($options{'logging'}) ? "checked" : "";
		printf "<input type=radio name=ufs_logging value=0 %s> $text{'no'}</td> </tr>\n",
			defined($options{'logging'}) ? "" : "checked";
		}
	else {
		print "<td><b>$text{'solaris_toosoon'}</b></td>\n";
		$options{toosoon} =~ /([0-9]+)([A-z])/;
		print "<td nowrap><input size=5 name=ufs_toosoon_time value='$1'>\n";
		print "<select name=ufs_toosoon_units>\n";
		foreach $u ('s', 'm', 'h', 'd', 'w', 'y') {
			printf "<option value=%s %s>%s</option>\n",
				$u, $2 eq $u ? "selected" : "", $text{"solaris_time_$u"};
			}
		print "</select></td> </tr>\n";
		}
	}
if ($_[0] eq "hsfs") {
	# Solaris hsfs is used for CDROMs
	print "<tr> <td><b>$text{'solaris_nrr'}</b></td>\n";
	printf "<td nowrap><input type=radio name=hsfs_nrr value=1 %s> $text{'yes'}\n",
		defined($options{"nrr"}) ? "checked" : "";
	printf "<input type=radio name=hsfs_nrr value=0 %s> $text{'no'}</td>\n",
		defined($options{"nrr"}) ? "" : "checked";

	print "<td><b>$text{'solaris_notraildot'}</b></td>\n";
	printf "<td nowrap><input type=radio name=hsfs_notraildot value=1 %s> $text{'yes'}\n",
		defined($options{"notraildot"}) ? "checked" : "";
	printf "<input type=radio name=hsfs_notraildot value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"notraildot"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_nomaplcase'}</b></td>\n";
	printf "<td nowrap><input type=radio name=hsfs_nomaplcase value=0 %s> $text{'yes'}\n",
		defined($options{"nomaplcase"}) ? "" : "checked";
	printf "<input type=radio name=hsfs_nomaplcase value=1 %s> $text{'no'}</td>\n",
		defined($options{"nomaplcase"}) ? "checked" : "";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf"<td nowrap><input type=radio name=hsfs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=hsfs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "pcfs") {
	# Solaris pcfs for for FAT filesystems. It doesn't have many options
	print "<tr> <td width=25%><b>$text{'solaris_ro'}</b></td> <td width=25%>\n";
	printf "<input type=radio name=pcfs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=pcfs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	if ($gconfig{'os_version'} >= 7) {
		print "<td><b>$text{'solaris_foldcase'}</b></td> <td>\n";
		printf "<input type=radio name=pcfs_foldcase value=1 %s> $text{'yes'}\n",
			defined($options{'foldcase'}) ? "checked" : "";
		printf "<input type=radio name=pcfs_foldcase value=0 %s> $text{'no'}</td>\n",
			defined($options{'foldcase'}) ? "" : "checked";
		}
	else {
		print "<td colspan=2></td> </tr>\n";
		}
	}
if ($_[0] eq "lofs") {
	# LOFS is a loopback filesystem
	print "<tr> <td><b>$text{'solaris_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=ufs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=ufs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=ufs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "tmpfs") {
	# Solaris tmpfs (virtual memory) filesystem.
	print "<tr> <td><b>$text{'solaris_size'}</b>&nbsp;&nbsp;&nbsp;</td>\n";
	printf"<td><input type=radio name=tmpfs_size_def value=1 %s> $text{'solaris_max'}\n",
		defined($options{"size"}) ? "" : "checked";
	printf"&nbsp;&nbsp;<input type=radio name=tmpfs_size_def value=0 %s>\n",
		defined($options{"size"}) ? "checked" : "";
	($tmpsz = $options{size}) =~ s/[A-z]+$//g;
	print "<input name=tmpfs_size size=6 value=\"$tmpsz\">\n";
	print "<select name=tmpfs_unit>\n";
	printf "<option value=m %s>MB</option>\n",
		$options{"size"} =~ /m$/ ? "selected" : "";
	printf "<option value=k %s>kB</option>\n",
		$options{"size"} =~ /k$/ ? "selected" : "";
	printf "<option value=b %s>bytes</option>\n",
		$options{"size"} !~ /(k|m)$/ ? "selected" : "";
	print "</select></td>\n";

	print "<td><b>$text{'solaris_nosuid'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=tmpfs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=tmpfs_nosuid value=0 %s> $text{'no'}</td>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	print "</tr>\n";
	}
if ($_[0] eq "swap") {
	# Solaris swap has no options
	print "<tr> <td><i>$text{'solaris_noopts'}</i></td> </tr>\n";
	}
if ($_[0] eq "cachefs") {
	# The caching filesystem has lots of options.. cachefs mounts can
	# be of an existing 'manually' mounted back filesystem, or of a
	# back-filesystem that has been automatically mounted by the cache.
	# The user should never see the automatic mountings made by cachefs.
	print "<tr> <td><b>$text{'solaris_backfs'}</b></td>\n";
	print "<td nowrap><select name=cfs_backfstype>\n";
	if (!defined($options{backfstype})) { $options{backfstype} = "nfs"; }
	foreach (&list_fstypes()) {
		if ($_ eq "cachefs") { next; }
		printf "<option value=\"$_\" %s>$_</option>\n",
			$_ eq $options{backfstype} ? "selected" : "";
		}
	print "</select></td>\n";

	print "<td><b>$text{'solaris_backpath'}</b></td>\n";
	printf"<td nowrap><input type=radio name=cfs_noback value=1 %s> $text{'solaris_auto'}\n",
		defined($options{"backpath"}) ? "" : "checked";
	printf "<input type=radio name=cfs_noback value=0 %s>\n",
		defined($options{"backpath"}) ? "checked" : "";
	print "<input size=10 name=cfs_backpath value=\"$options{backpath}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_cachedir'}</b></td>\n";
	printf "<td nowrap><input size=10 name=cfs_cachedir value=\"%s\"></td>\n",
		defined($options{"cachedir"}) ? $options{"cachedir"} : "/cache";

	print "<td><b>$text{'solaris_wmode'}</b></td>\n";
	printf"<td nowrap><input type=radio name=cfs_wmode value=0 %s> $text{'solaris_waround'}\n",
		defined($options{"non-shared"}) ? "" : "checked";
	printf "<input type=radio name=cfs_wmode value=1 %s> $text{'solaris_nshared'}\n",
		defined($options{"non-shared"}) ? "checked" : "";
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_con'}</b></td>\n";
	print "<td><select name=cfs_con>\n";
	print "<option value=1>$text{'solaris_period'}</option>\n";
	printf "<option value=0 %s>$text{'solaris_never'}</option>\n",
		defined($options{"noconst"}) ? "selected" : "";
	printf "<option value=2 %s>$text{'solaris_demand'}</option>\n",
		defined($options{"demandconst"}) ? "selected" : "";
	print "</select></td>\n";

	print "<td><b>$text{'solaris_local'}</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_local value=1 %s> $text{'yes'}\n",
		defined($options{"local-access"}) ? "checked" : "";
	printf "<input type=radio name=cfs_local value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"local-access"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=cfs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=cfs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "autofs") {
	# Autofs has lots of options, depending on the type of file
	# system being automounted.. the fstype options determines this
	local($fstype);
	$fstype = $options{fstype} eq "" ? "nfs" : $options{fstype};
	if ($gconfig{'os_version'} >= 2.6) {
		print "<tr> <td><b>$text{'solaris_nobrowse'}</b></td> <td>\n";
		printf "<input type=radio name=auto_nobrowse value=0 %s> $text{'yes'}\n",
			defined($options{'nobrowse'}) ? "" : "checked";
		printf "<input type=radio name=auto_nobrowse value=1 %s> $text{'no'}\n",
			defined($options{'nobrowse'}) ? "checked" : "";
		print "</td> <td colspan=2></td> </tr>\n";
		}
	&generate_options($fstype);
	print "<input type=hidden name=autofs_fstype value=\"$fstype\">\n";
	}
if ($_[0] eq "rumba") {
	# SMB filesystems have a few options..
	print "<tr> <td><b>$text{'solaris_mname'}</b></td>\n";
	printf "<td><input type=radio name=rumba_mname_def value=1 %s> $text{'solaris_auto'}\n",
		defined($options{"machinename"}) ? "" : "checked";
	printf "<input type=radio name=rumba_mname_def value=0 %s>\n",
		defined($options{"machinename"}) ? "checked" : "";
	print "<input size=10 name=rumba_mname value=\"$options{machinename}\"></td>\n";

	print "<td><b>$text{'solaris_cname'}</b></td>\n";
	printf "<td><input type=radio name=rumba_cname_def value=1 %s> $text{'solaris_auto'}\n",
		defined($options{"clientname"}) ? "" : "checked";
	printf "<input type=radio name=rumba_cname_def value=0 %s>\n",
		defined($options{"clientname"}) ? "checked" : "";
	print "<input size=10 name=rumba_cname value=\"$options{clientname}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_username'}</b></td>\n";
	print "<td><input name=rumba_username size=15 value=\"$options{username}\"></td>\n";

	print "<td><b>$text{'solaris_password'}</b></td>\n";
	print "<td><input type=password name=rumba_password size=15 value=\"$options{password}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'solaris_uid'}</b></td>\n";
	printf "<td><input name=rumba_uid size=8 value=\"%s\">\n",
		defined($options{'uid'}) ? getpwuid($options{'uid'}) : "";
	print &user_chooser_button("rumba_uid", 0),"</td>\n";

	print "<td><b>$text{'solaris_gid'}</b></td>\n";
	printf "<td><input name=rumba_gid size=8 value=\"%s\">\n",
		defined($options{'gid'}) ? getgrgid($options{'gid'}) : "";
	print &group_chooser_button("rumba_gid", 0),"</td>\n";

	print "<tr> <td><b>$text{'solaris_fmode'}</b></td>\n";
	printf "<td><input name=rumba_fmode size=5 value=\"%s\"></td>\n",
		defined($options{fmode}) ? $options{fmode} : "755";

	print "<td><b>$text{'solaris_dmode'}</b></td>\n";
	printf "<td><input name=rumba_dmode size=5 value=\"%s\"></td> </tr>\n",
		defined($options{dmode}) ? $options{dmode} : "755";

	print "<tr> <td><b>$text{'solaris_readwrite'}</b></td>\n";
	printf"<td nowrap><input type=radio name=rumba_readwrite value=1 %s> $text{'yes'}\n",
		defined($options{"readwrite"}) ? "checked" : "";
	printf "<input type=radio name=rumba_readwrite value=0 %s> $text{'no'}</td>\n",
		defined($options{"readwrite"}) ? "" : "checked";

	print "<td><b>$text{'solaris_readonly'}</b></td>\n";
	printf"<td nowrap><input type=radio name=rumba_readonly value=1 %s> $text{'yes'}\n",
		defined($options{"readonly"}) ? "checked" : "";
	printf "<input type=radio name=rumba_readonly value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"readonly"}) ? "" : "checked";

	print "<tr> <td><b>$text{'solaris_noupper'}</b></td>\n";
	printf"<td nowrap><input type=radio name=rumba_noupper value=0 %s> $text{'yes'}\n",
		defined($options{"noupper"}) ? "" : "checked";
	printf "<input type=radio name=rumba_noupper value=1 %s> $text{'no'}</td>\n",
		defined($options{"noupper"}) ? "checked" : "";

	print "<td><b>$text{'solaris_attr'}</b></td>\n";
	printf"<td nowrap><input type=radio name=rumba_attr value=1 %s> $text{'yes'}\n",
		defined($options{"attr"}) ? "checked" : "";
	printf "<input type=radio name=rumba_attr value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"attr"}) ? "" : "checked";
	}
if ($_[0] eq "udfs") {
	# Solaris udfs is used for DVDs
	print "<tr> <td><b>$text{'solaris_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=udfs_ro value=1 %s> $text{'yes'}\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=udfs_ro value=0 %s> $text{'no'}</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'solaris_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=udfs_nosuid value=1 %s> $text{'yes'}\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=udfs_nosuid value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "xmemfs") {
	# Solaris xmemfs (virtual memory) filesystem.
	print "<tr> <td><b>$text{'solaris_size'}</b>&nbsp;&nbsp;&nbsp;</td>\n";
	printf"<td><input type=radio name=xmemfs_size_def value=1 %s> $text{'solaris_max'}\n",
		defined($options{"size"}) ? "" : "checked";
	printf"&nbsp;&nbsp;<input type=radio name=xmemfs_size_def value=0 %s>\n",
		defined($options{"size"}) ? "checked" : "";
	($tmpsz = $options{size}) =~ s/[A-z]+$//g;
	print "<input name=xmemfs_size size=6 value=\"$tmpsz\">\n";
	print "<select name=xmemfs_unit>\n";
	printf "<option value=m %s>MB</option>\n",
		$options{"size"} =~ /m$/ ? "selected" : "";
	printf "<option value=k %s>kB</option>\n",
		$options{"size"} =~ /k$/ ? "selected" : "";
	printf "<option value=b %s>bytes</option>\n",
		$options{"size"} !~ /(k|m)$/ ? "selected" : "";
	print "</select></td>\n";

	print "<td><b>$text{'solaris_largebsize'}</b></td>\n";
	printf "<td nowrap><input type=radio name=xmemfs_largebsize value=1 %s> $text{'yes'}\n",
		defined($options{"largebsize"}) ? "checked" : "";
	printf "<input type=radio name=xmemfs_largebsize value=0 %s> $text{'no'}</td> </tr>\n",
		defined($options{"largebsize"}) ? "" : "checked";
	}
}


# check_location(type)
# Parse and check inputs from %in, calling &error() if something is wrong.
# Returns the location string for storing in the fstab file
sub check_location
{
if ($_[0] eq "nfs") {
	local($out, $temp, $mout, $dirlist);

	if ($in{'nfs_serv'} == 1) {
		# multiple servers listed.. assume the user has a brain
		return $in{'nfs_list'};
		}
	elsif ($in{'nfs_serv'} == 2) {
		# NFS url.. check syntax
		if ($in{'nfs_url'} !~ /^nfs:\/\/([^\/ ]+)(\/([^\/ ]*))?$/) {
			&error(&text('solaris_eurl', $in{'nfs_url'}));
			}
		return $in{'nfs_url'};
		}

	# Use dfshares to see if the host exists and is up
	if ($in{nfs_host} !~ /^\S+$/) {
		&error(&text('solaris_ehost', $in{'nfs_host'}));
		}
	$out = &backquote_command("dfshares '$in{nfs_host}' 2>&1");
	if ($out =~ /Unknown host/) {
		&error(&text('solaris_ehost2', $in{'nfs_host'}));
		}
	elsif ($out =~ /Timed out/) {
		&error(&text('solaris_edown', $in{'nfs_host'}));
		}
	elsif ($out =~ /Program not registered/) {
		&error(&text('solaris_enfs', $in{'nfs_host'}));
		}

	# Try a test mount to see if filesystem is available
	foreach (split(/\n/, $out)) {
		if (/^\s*([^ :]+):(\/\S+)\s+/) { $dirlist .= "$2\n"; }
		}
	if ($in{nfs_dir} !~ /^\S+$/) {
		&error(&text('solaris_enfsdir', $in{'nfs_dir'},
			     $in{'nfs_host'}, "<pre>$dirlist</pre>"));
		}
	$temp = &transname();
	&make_dir($temp, 0755);
	$mout = &backquote_command("mount $in{nfs_host}:$in{nfs_dir} $temp 2>&1");
	if ($mout =~ /No such file or directory/) {
		rmdir($temp);
		&error(&text('solaris_enfsdir', $in{'nfs_dir'},
			     $in{'nfs_host'}, "<pre>$dirlist</pre>"));
		}
	elsif ($mout =~ /Permission denied/) {
		rmdir($temp);
		&error(&text('solaris_enfsperm', $in{'nfs_dir'}, $in{'nfs_host'}));
		}
	elsif ($?) {
		rmdir($temp);
		&error(&text('solaris_enfsmount', "<tt>$mout</tt>"));
		}
	# It worked! unmount
	&execute_command("umount $temp");
	&unlink_file($temp);
	return "$in{nfs_host}:$in{nfs_dir}";
	}
elsif ($_[0] eq "ufs" || $_[0] eq "pcfs") {
	# Get the device name
	if ($in{ufs_dev} == 0) {
		$dv = $in{'ufs_disk'};
		}
	elsif ($in{ufs_dev} == 1) {
		$in{ufs_md} =~ /^[0-9]+$/ ||
			&error(&text('solaris_eraid', $in{'ufs_md'}));
		$dv = "/dev/md/dsk/d$in{ufs_md}";
		}
	else {
		$in{ufs_path} =~ /^\/\S+$/ ||
			&error(&text('solaris_epath', $in{'ufs_path'}));
		$dv = $in{ufs_path};
		}

	&fstyp_check($dv, $_[0]);
	return $dv;
	}
elsif ($_[0] eq "hsfs" || $_[0] eq "udfs") {
	# Get the device name
	if ($in{ufs_dev} == 0) {
		$in{ufs_c} =~ /^[0-9]+$/ ||
			&error(&text('solaris_ectrlr', $in{'ufs_c'}));
		$in{ufs_t} =~ /^[0-9]+$/ ||
			&error(&text('solaris_etarget', $in{'ufs_t'}));
		$in{ufs_d} =~ /^[0-9]+$/ ||
			&error(&text('solaris_eunit', $in{'ufs_d'}));
		$in{ufs_s} =~ /^[0-9]+$/ ||
			&error(&text('solaris_epart', $in{'ufs_s'}));
		$dv = "/dev/dsk/c$in{ufs_c}t$in{ufs_t}d$in{ufs_d}s$in{ufs_s}";
		}
	else {
		$in{ufs_path} =~ /^\/\S+$/ ||
			&error(&text('solaris_epath', $in{'ufs_path'}));
		$dv = $in{ufs_path};
		}

	return $dv;
	}
elsif ($_[0] eq "lofs") {
	# Get and check the original directory
	$dv = $in{'lofs_src'};
	if (!(-r $dv)) { &error(&text('solaris_eexist', $dv)); }
	if (!(-d $dv)) { &error(&text('solaris_edir', $dv)); }
	return $dv;
	}
elsif ($_[0] eq "swap") {
	if ($in{swap_dev} == 0) {
		$dv = $in{'swap_disk'};
		}
	else { $dv = $in{swap_path}; }

	if (!open(SWAPFILE, $dv)) {
		if ($! =~ /No such file/ && $in{swap_dev}) {
			if ($dv !~ /^\/dev/) {
				&swap_form($dv);
				}
			else {
				&error(&text('solaris_eswapfile', $dv));
				}
			}
		elsif ($! =~ /No such file/) {
			&error(&text('solaris_etarget', $in{'swap_t'}));
			}
		elsif ($! =~ /No such device or address/) {
			&error(&text('solaris_epart', $in{'swap_s'}));
			}
		else {
			&error(&text('solaris_eopen', $dv, $!));
			}
		}
	close(SWAPFILE);
	return $dv;
	}
elsif ($_[0] eq "tmpfs") {
	# Ram-disk filesystems have no location
	return "swap";
	}
elsif ($_[0] eq "xmemfs") {
	# Large ram-disk filesystems have no location
	return "xmem";
	}
elsif ($_[0] eq "cachefs") {
	# In order to check the location for the caching filesystem, we need
	# to check the back filesystem
	if (!$in{cfs_noback}) {
		# The back filesystem is manually mounted.. hopefully
		local($bidx, @mlist, @binfo);
		$bidx = &get_mounted($in{cfs_backpath}, "*");
		if ($bidx < 0) {
			&error(&text('solaris_ebackfs', $in{'cfs_backpath'}));
			}
		@mlist = &list_mounted();
		@binfo = @{$mlist[$bidx]};
		if ($binfo[2] ne $in{cfs_backfstype}) {
			&error(&text('solaris_ebacktype', $binfo[2], $in{'cfs_backfstype'}));
			}
		}
	else {
		# Need to automatically mount the back filesystem.. check
		# it for sanity first.
		# But HOW?
		$in{cfs_src} =~ /^\S+$/ ||
			&error(&text('solaris_ecsrc', $in{'cfs_src'}));
		}
	return $in{cfs_src};
	}
elsif ($_[0] eq "autofs") {
	# An autofs filesystem can be either mounted from the special
	# -hosts and -xfn maps, or from a normal map. The map can be a file
	# name (if it starts with /), or an NIS map (if it doesn't)
	if ($in{autofs_type} == 0) {
		# Normal map
		$in{autofs_map} =~ /\S/ ||
			&error($text{'solaris_eautomap'});
		if ($in{autofs_map} =~ /^\// && !(-r $in{autofs_map})) {
			&error(&text('solaris_eautofile', $in{'autofs_map'}));
			}
		return $in{autofs_map};
		}
	elsif ($in{autofs_type} == 1) {
		# Special hosts map (automount all shares from some host)
		return "-hosts";
		}
	else {
		# Special FNS map (not sure what this does)
		return "-xfn";
		}
	}
elsif ($_[0] eq "rumba") {
	# Cannot check much here..
	return "\\\\$in{rumba_server}\\$in{rumba_share}";
	}
}


# fstyp_check(device, type)
# Check if some device exists, and contains a filesystem of the given type,
# using the fstyp command.
sub fstyp_check
{
local($out, $part, $found);

# Check if the device/partition actually exists
if ($_[0] =~ /^\/dev\/dsk\/c(.)t(.)d(.)s(.)$/) {
	# mounting a normal scsi device..
	$out = &backquote_command("prtvtoc -h $_[0] 2>&1");
	if ($out =~ /No such file or directory|No such device or address/) {
		&error(&text('solaris_etarget2', $_[0]));
		}
	$part = $4;
	foreach (split(/\n/, $out)) {
		/^\s+([0-9]+)\s+([0-9]+)/;
		if ($1 == $part) {
			$found = 1; last;
			}
		}
	if (!$found) {
		&error(&text('solaris_epart2', $_[0]));
		}
	}
elsif ($_[0] =~ /^\/dev\/md\/dsk\/d(.)$/) {
	# mounting a multi-disk (raid) device..
	$out = &backquote_command("prtvtoc -h $_[0] 2>&1");
	if ($out =~ /No such file or directory|No such device or address/) {
		&error(&text('solaris_eraid2', $_[0]));
		}
	if ($out !~ /\S/) {
		&error(&text('solaris_enopart', $_[0]));
		}
	}
else {
	# Some other device
	if (!open(DEV, $_[0])) {
		if ($! =~ /No such file or directory/) {
			&error(&text('solaris_edevfile', $_[0]));
			}
		elsif ($! =~ /No such device or address/) {
			&error(&text('solaris_edevice', $_[0]));
			}
		}
	close(DEV);
	}

# Check the filesystem type
$out = &backquote_command("fstyp $_[0] 2>&1");
if ($out =~ /^([A-Za-z0-9]+)\n$/) {
	if ($1 eq $_[1]) { return; }
	else {
		# Wrong filesystem type
		&error(&text('solaris_efstyp', $_[0], &fstype_name($1)));
		}
	}
else {
	&error(&text('solaris_efstyp2', $out));
	}
}


# check_options(type)
# Read options for some filesystem from %in, and use them to update the
# %options array. Options handled by the user interface will be set or
# removed, while unknown options will be left untouched.
sub check_options
{
local($k, @rv);
if ($_[0] eq "nfs") {
	# NFS has lots of options to parse
	if ($in{'nfs_ro'}) {
		# Read-only
		$options{"ro"} = ""; delete($options{"rw"});
		}
	else {
		# Read-write
		$options{"rw"} = ""; delete($options{"ro"});
		}

	delete($options{'quota'}); delete($options{'noquota'});
	if ($in{'nfs_quota'}) { $options{'quota'} = ""; }

	delete($options{"nosuid"}); delete($options{"suid"});
	if ($in{nfs_nosuid}) { $options{"nosuid"} = ""; }

	delete($options{"grpid"});
	if ($in{nfs_grpid}) { $options{"grpid"} = ""; }

	delete($options{"soft"}); delete($options{"hard"});
	if ($in{nfs_soft}) { $options{"soft"} = ""; }

	delete($options{"bg"}); delete($options{"fg"});
	if ($in{nfs_bg}) { $options{"bg"} = ""; }

	delete($options{"intr"}); delete($options{"nointr"});
	if ($in{nfs_nointr}) { $options{"nointr"} = ""; }

	delete($options{"vers"});
	if (!$in{nfs_vers_def}) { $options{"vers"} = $in{nfs_vers}; }

	delete($options{"proto"});
	if ($in{nfs_proto} ne "") { $options{"proto"} = $in{nfs_proto}; }

	delete($options{"port"});
	if (!$in{nfs_port_def}) { $options{"port"} = $in{nfs_port}; }

	delete($options{"timeo"});
	if (!$in{nfs_timeo_def}) { $options{"timeo"} = $in{nfs_timeo}; }

	delete($options{"secure"}); delete($options{"kerberos"});
	delete($options{"sec"});
	if ($gconfig{'os_version'} >= 2.6) {
		if ($in{'nfs_auth'}) { $options{'sec'} = $in{'nfs_auth'}; }
		}
	else {
		if ($in{'nfs_auth'} eq "dh") { $options{"secure"} = ""; }
		elsif ($in{'nfs_auth'} eq "krb") { $options{"kerberos"} = ""; }
		}

	if ($gconfig{'os_version'} >= 7) {
		delete($options{'public'});
		$options{'public'} = "" if ($in{'nfs_public'});
		}
	}
elsif ($_[0] eq "ufs") {
	# UFS also has lots of options..
	if ($in{ufs_ro}) {
		# read-only (and thus no quota)
		$options{"ro"} = ""; delete($options{"rw"});
		delete($options{"rq"}); delete($options{"quota"});
		}
	elsif ($in{ufs_quota}) {
		# read-write, with quota
		delete($options{"ro"}); $options{"rw"} = "";
		$options{"quota"} = "";
		}
	else {
		# read-write, without quota
		delete($options{"ro"}); $options{"rw"} = "";
		delete($options{"quota"});
		}

	delete($options{"nosuid"});
	if ($in{ufs_nosuid}) { $options{"nosuid"} = ""; }

	delete($options{"intr"}); delete($options{"nointr"});
	if ($in{ufs_nointr}) { $options{"nointr"} = ""; }

	delete($options{"onerror"});
	if ($in{ufs_onerror} ne "panic") {
		$options{"onerror"} = $in{ufs_onerror};
		}

	if ($gconfig{'os_version'} >= 7) {
		if ($gconfig{'os_version'} >= 8) {
			delete($options{'noatime'});
			delete($options{'dfratime'}); delete($options{'nodfratime'});
			if ($in{'ufs_noatime'} == 0) { $options{'nodfratime'} = ""; }
			elsif ($in{'ufs_noatime'} == 2) { $options{'noatime'} = ""; }
			}
		else {
			delete($options{'noatime'});
			$options{'noatime'} = "" if ($in{'ufs_noatime'});
			}

		delete($options{'forcedirectio'});
		delete($options{'noforcedirectio'});
		$options{'forcedirectio'} = "" if ($in{'ufs_force'});

		delete($options{'nolargefiles'});delete($options{'largefiles'});
		$options{'nolargefiles'} = "" if ($in{'ufs_nolarge'});

		delete($options{'logging'}); delete($options{'nologging'});
		$options{'logging'} = "" if ($in{'ufs_logging'});
		}
	else {
		delete($options{"toosoon"});
		if ($in{ufs_toosoon_time}) {
			$options{"toosoon"} = $in{ufs_toosoon_time}.
					      $in{ufs_toosoon_units};
			}
		}
	}
elsif ($_[0] eq "lofs") {
	# LOFS has a few options
	if ($in{'nfs_ro'}) {
		# Read-only
		$options{"ro"} = ""; delete($options{"rw"});
		}
	else {
		# Read-write
		$options{"rw"} = ""; delete($options{"ro"});
		}

	delete($options{"nosuid"});
	if ($in{ufs_nosuid}) { $options{"nosuid"} = ""; }
	}
elsif ($_[0] eq "swap") {
	# Swap has no options to parse
	}
elsif ($_[0] eq "pcfs") {
	# PCFS has only 2 options
	delete($options{'ro'}); delete($options{'rw'});
	$options{'ro'} = "" if ($in{'pcfs_ro'});

	delete($options{'foldcase'}); delete($options{'nofoldcase'});
	$options{'foldcase'} = "" if ($in{'pcfs_foldcase'});
	}
elsif ($_[0] eq "hsfs") {
	# Options for ISO-9660 filesystems
	delete($options{'nrr'});
	$options{'nrr'} = "" if ($in{'hsfs_nrr'});

	delete($options{"notraildot"});
	$options{"notraildot"} = "" if ($in{'hsfs_notraildot'});

	delete($options{'nomaplcase'});
	$options{'nomaplcase'} = "" if ($in{'hsfs_nomaplcase'});

	delete($options{'nosuid'});
	$options{'nosuid'} = "" if ($in{'hsfs_nosuid'});
	}
elsif ($_[0] eq "tmpfs") {
	# Ram-disk filesystems have only two options
	delete($options{"size"});
	if (!$in{"tmpfs_size_def"}) {
		$options{"size"} = "$in{tmpfs_size}$in{tmpfs_unit}";
		}

	delete($options{"nosuid"});
	if ($in{'tmpfs_nosuid'}) { $options{"nosuid"} = ""; }
	}
elsif ($_[0] eq "xmemfs") {
	# Large ram-disk filesystems have only two options
	delete($options{"size"});
	if (!$in{"xmemfs_size_def"}) {
		$options{"size"} = "$in{xmemfs_size}$in{xmemfs_unit}";
		}

	delete($options{"largebsize"});
	if ($in{'xmemfs_largebsize'}) { $options{"largebsize"} = ""; }

	delete($options{'rw'});
	}
elsif ($_[0] eq "cachefs") {
	# The caching filesystem has lots of options
	$options{"backfstype"} = $in{"cfs_backfstype"};

	delete($options{"backpath"});
	if (!$in{"cfs_noback"}) {
		# A back filesystem was given..  (alreadys checked)
		$options{"backpath"} = $in{"cfs_backpath"};
		}

	if ($in{"cfs_cachedir"} !~ /^\/\S+/) {
		&error(&text('solaris_ecachedir', $in{'cfs_cachedir'}));
		}
	$options{"cachedir"} = $in{"cfs_cachedir"};

	delete($options{"write-around"}); delete($options{"non-shared"});
	if ($in{"cfs_wmode"}) {
		$options{"non-shared"} = "";
		}

	delete($options{"noconst"}); delete($options{"demandconst"});
	if ($in{"cfs_con"} == 0) { $options{"noconst"} = ""; }
	elsif ($in{"cfs_con"} == 2) { $options{"demandconst"} = ""; }

	delete($options{"ro"}); delete($options{"rw"});
	if ($in{"cfs_ro"}) { $options{"ro"} = ""; }

	delete($options{"suid"}); delete($options{"nosuid"});
	if ($in{"cfs_nosuid"}) { $options{"nosuid"} = ""; }
	}
elsif ($_[0] eq "autofs") {
	# The options for autofs depend on the type of the automounted
	# filesystem.. 
	$options{"fstype"} = $in{"autofs_fstype"};
	if ($gconfig{'os_version'} >= 2.6) {
		delete($options{'nobrowse'}); delete($options{'browse'});
		$options{'nobrowse'} = "" if ($in{'auto_nobrowse'});
		}
	return &check_options($options{"fstype"});
	}
elsif ($_[0] eq "rumba") {
	# Options for smb filesystems..
	delete($options{machinename});
	if (!$in{rumba_mname_def}) { $options{machinename} = $in{rumba_mname}; }

	delete($options{clientname});
	if (!$in{rumba_cname_def}) { $options{clientname} = $in{rumba_cname}; }

	delete($options{username});
	if ($in{rumba_username}) { $options{username} = $in{rumba_username}; }

	delete($options{password});
	if ($in{rumba_password}) { $options{password} = $in{rumba_password}; }

	delete($options{uid});
	if ($in{rumba_uid} ne "") { $options{uid} = getpwnam($in{rumba_uid}); }

	delete($options{gid});
	if ($in{rumba_gid} ne "") { $options{gid} = getgrnam($in{rumba_gid}); }

	delete($options{fmode});
	if ($in{rumba_fmode} !~ /^[0-7]{3}$/) {
		&error(&text('solaris_efmode', $in{'rumba_fmode'}));
		}
	elsif ($in{rumba_fmode} ne "755") { $options{fmode} = $in{rumba_fmode}; }

	delete($options{dmode});
	if ($in{rumba_dmode} !~ /^[0-7]{3}$/) {
		&error(&text('solaris_edmode', $in{'rumba_dmode'}));
		}
	elsif ($in{rumba_dmode} ne "755") { $options{dmode} = $in{rumba_dmode}; }

	delete($options{'readwrite'});
	if ($in{'rumba_readwrite'}) { $options{'readwrite'} = ""; }

	delete($options{'readonly'});
	if ($in{'rumba_readonly'}) { $options{'readonly'} = ""; }

	delete($options{'attr'});
	if ($in{'rumba_attr'}) { $options{'attr'} = ""; }

	delete($options{'noupper'});
	if ($in{'rumba_noupper'}) { $options{'noupper'} = ""; }
	}
elsif ($_[0] eq "udfs") {
	# The DVD filesystem has only 2 options
	delete($options{'ro'}); delete($options{'rw'});
	$options{'ro'} = "" if ($in{'udfs_ro'});

	delete($options{"nosuid"});
	if ($in{'udfs_nosuid'}) { $options{"nosuid"} = ""; }
	}

# Return options string
foreach $k (keys %options) {
	if ($options{$k} eq "") { push(@rv, $k); }
	else { push(@rv, "$k=$options{$k}"); }
	}
return @rv ? join(',' , @rv) : "-";
}


# create_swap(path, size, units)
# Attempt to create a swap file 
sub create_swap
{
local($out);
$out = &backquote_logged("mkfile $_[1]$_[2] $_[0] 2>&1");
if ($?) {
	&unlink_file($_[0]);
	return "mkfile failed : $out";
	}
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
foreach (split(/\n/, $out)) {
	if (/^(\/\S*)\s+(.*)$/) {
		push(@$dref, $1); push(@$cref, $2);
		}
	}
return undef;
}

# broadcast_addr()
# Returns a useable broadcast address for finding NFS servers
sub broadcast_addr
{
local($out);
$out = &backquote_command("ifconfig -a 2>&1", 1);
if ($out =~ /broadcast\s+(\S+)/) { return $1; }
return "255.255.255.255";
}

# device_name(device)
# Converts a device name to a human-readable form
sub device_name
{
return $_[0] =~ /\/dev\/dsk\/c(\d+)t(\d+)d(\d+)s(\d+)$/ ?
	&text('solaris_scsidev', "$1", "$2", "$3", "$4") :
       $_[0] =~ /^\/dev\/md\/dsk\/d([0-9]+)$/ ?
	&text('solaris_mddev', "$1") :
       $_[0] =~ /^\/dev\/dsk\/c(\d+)d(\d+)s(\d+)$/ ?
	&text('solaris_idedev', "$1", "$2", "$3") :
       $_[0] eq "-hosts" ?
	$text{'solaris_autohosts'} :
       $_[0] eq "-xfn" ?
	$text{'solaris_autoxfn'} :
	$_[0];
}

sub files_to_lock
{
return ( $config{'fstab_file'}, $config{'autofs_file'} );
}

1;
