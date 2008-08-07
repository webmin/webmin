# macos-lib.pl
# Mount table functions for OSX
# Only options for currently mounted filesystems are supported at the moment.

# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
# Under FreeBSD, there seems to be no way to get additional mount options
# used by filesystems like NFS etc. Even getting the full details of mounted
# filesystems requires C code! So we have to call a specially-written external
# program to get the mount list
sub list_mounted
{
# get the list of mounted filesystems
local(@rv, $_);
local $arch = &backquote_command("uname -m");
local $cmd;
if ($arch =~ /power/) {
	$cmd = "macos-mounts";
	&compile_program($cmd, '.*power.*');
	}
else {
	$cmd = "macos-mounts-intel";
	&compile_program($cmd, 'i386');
	}
open(CMD, "$module_config_directory/$cmd |");
while(<CMD>) {
	local @p = split(/\t/, $_);
	if ($p[2] eq "procfs" || $p[1] eq "procfs") { $p[1] = $p[2] = "proc"; }
	push(@rv, \@p);
	}
close(CMD);
return @rv;
}


# mount_dir(directory, device, type, options)
# Mount a new directory from some device, with some options. Returns 0 if ok,
# or an error string if failed
sub mount_dir
{
local($out, $opts, $shar, %options, %smbopts);

$opts = $_[3] eq "-" ? "" : "-o \"$_[3]\"";
$opts = join(',', grep { !/quota/ } split(/,/, $opts));
$out = &backquote_logged("mount -t $_[2] $opts $_[1] $_[0] 2>&1");
if ($?) { return "<pre>$out</pre>"; }

return 0;
}


# unmount_dir(directory, device, type)
# Unmount a directory that is currently mounted. Returns 0 if ok,
# or an error string if failed
sub unmount_dir
{
local($out, %smbopts, $dir);
$out = &backquote_logged("umount $_[0] 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return 0;
}


sub list_mounts
{
return ( );
}

# mount_modes(type)
# Given a filesystem type, returns 4 numbers that determine how the file
# system can be mounted, and whether it can be fsck'd
# The first is:
#  0 - cannot be permanently recorded
#	(smbfs under linux)
#  1 - can be permanently recorded, and is always mounted at boot
#	(swap under linux)
#  2 - can be permanently recorded, and may or may not be mounted at boot
#	(most normal filesystems)
# The second is:
#  0 - mount is always permanent => mounted when saved
#	(swap under linux)
#  1 - doesn't have to be permanent
#	(normal fs types)
# The third is:
#  0 - cannot be fsck'd at boot time
#  1 - can be be fsck'd at boot
# The fourth is:
#  0 - can be unmounted
#  1 - cannot be unmounted
sub mount_modes
{
if ($_[0] eq "swap")
	{ return (2, 1, 0, 1); }
elsif ($_[0] eq "ufs")
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
if ($_[0] eq "proc" || $_[0] eq "swap") { return (); }
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
local @rv = ("ufs", "nfs", "cd9660", "msdos", "swap");
push(@rv, "ext2fs") if (&has_command("mount_ext2fs"));
push(@rv, "ntfs") if (&has_command("mount_ntfs"));
return @rv;
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ufs", "FreeBSD Unix Filesystem",
	  "nfs","Network Filesystem",
	  "hfs","Macintosh Filesystem",
	  "msdos","MS-DOS Filesystem",
	  "volfs","Volumes Filesystem",
	  "swap","Virtual Memory");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}

sub device_name
{
return $_[0];
}

sub files_to_lock
{
return ( );
}

1;

