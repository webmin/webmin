# osf1-lib.pl
# Filesystem functions for OSF1

# Return information about a filesystem, in the form:
#  directory, device, type, options, fsck_order, mount_at_boot
# If a field is unused or ignored, a - appears instead of the value.
# Swap-filesystems (devices or files mounted for VM) have a type of 'swap',
# and 'swap' in the directory field
sub list_mounts
{
local(@rv, @p, $_, $i); $i = 0;

# List normal filesystem mounts
open(FSTAB, $config{fstab_file});
while(<FSTAB>) {
	chop; s/^#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[3] eq "swap") { $p[2] = "swap"; }
	$rv[$i++] = [ $p[1], $p[0], $p[2], $p[3], $p[5], 1 ];
	}
close(FSTAB);

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
close(FSTAB);

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
close(FSTAB);

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
}


# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
# For swap files, the directory will be 'swap'
sub list_mounted
{
local(@rv, @p, $_, $i, $r);
&open_execute_command(MOUNT, "/usr/sbin/mount", 1, 1);
while(<MOUNT>) {
	if (/^(\S+)\s+on\s+(\S+)\s+type\s+(\S+)\s+\((.*)\)/) {
		local $opts = $3;
		$opts =~ s/\s+//g;
		push(@rv, [ $2, $1, $3, $opts ]);
		}
	}
close(MOUNT);
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
				return "The directory $options{cachedir} ".
				       "already exists. Delete it";
				}
			$out = &backquote_logged("cfsadmin -c $options{cachedir} 2>&1");
			if ($?) { return $out; }
			}
		}
	if ($_[2] eq "rumba") {
		# call 'rumba' to mount
		local(%options, $shortname, $shar, $opts, $rv);
		&parse_options("rumba", $_[3]);
		$shortname = hostname();
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
		return "$_[0] is busy";
		}
	if (&backquote_command("cat /etc/mnttab", 1) =~
	    /rumba-(\d+)\s+$dir\s+nfs/) {
		&kill_logged('TERM', $1) || return "Failed to kill rumba";
		}
	else {
		return "Failed to find rumba pid";
		}
	sleep(1);
	}
else {
	$out = &backquote_logged("umount $_[0] 2>&1");
	}
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
    /Mounted on\n\S+\s+(\S+)\s+\S+\s+(\S+)/) {
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
return ("ufs", "nfs", "advfs");
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ufs","OSF Unix Filesystem",
	  "nfs","Network Filesystem",
	  "advfs","Advanced File System",
	  "procfs","Process Image Filesystem");
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
        $_[0] eq "autofs" || $_[0] eq "lofs" || $_[0] eq "rumba");
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
		&error("The SCSI target for '$_[0]' does not exist");
		}
	$part = $4;
	foreach (split(/\n/, $out)) {
		/^\s+([0-9]+)\s+([0-9]+)/;
		if ($1 == $part) {
			$found = 1; last;
			}
		}
	if (!$found) {
		&error("The SCSI partition for '$_[0]' does not exist");
		}
	}
elsif ($_[0] =~ /^\/dev\/md\/dsk\/d(.)$/) {
	# mounting a multi-disk (raid) device..
	$out = &backquote_command("prtvtoc -h $_[0] 2>&1");
	if ($out =~ /No such file or directory|No such device or address/) {
		&error("The RAID device for '$_[0]' does not exist");
		}
	if ($out !~ /\S/) {
		&error("No partitions on '$_[0]' ??");
		}
	}
else {
	# Some other device
	if (!open(DEV, $_[0])) {
		if ($! =~ /No such file or directory/) {
			&error("The device file '$_[0]' does not exist");
			}
		elsif ($! =~ /No such device or address/) {
			&error("The device for '$_[0]' does not exist");
			}
		}
	close(DEV);
	}

# Check the filesystem type
$out = &backquote_command("fstyp $_[0] 2>&1");
if ($out =~ /^([A-z0-9]+)\n$/) {
	if ($1 eq $_[1]) { return; }
	else {
		# Wrong filesystem type
		&error("The device '$_[0]' is formatted as a ".
		       &fstype_name($1));
		}
	}
else {
	&error("Failed to check filesystem type : $out");
	}
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

sub device_name
{
return $_[0];
}

sub files_to_lock
{
return ( $config{'fstab_file'} );
}

1;
