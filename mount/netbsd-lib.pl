# openbsd-lib.pl
# Mount table functions for openbsd

$uname_release = `uname -r`;

# Return information about a filesystem, in the form:
#  directory, device, type, options, fsck_order, mount_at_boot
# If a field is unused or ignored, a - appears instead of the value.
# Swap-filesystems (devices or files mounted for VM) have a type of 'swap',
# and 'swap' in the directory field
sub list_mounts
{
local(@rv, @p, @o, $_, $i, $j); $i = 0;

# Get /etc/fstab mounts
open(FSTAB, $config{'fstab_file'});
while(<FSTAB>) {
	local(@o, $at_boot);
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[2] eq "proc" || $p[2] eq "procfs") { $p[2] = $p[0] = "proc"; }
	if ($p[2] eq "swap") { $p[1] = "swap"; }
	$rv[$i] = [ $p[1], $p[0], $p[2] ];
	$rv[$i]->[5] = "yes";
	@o = split(/,/ , $p[3] eq "defaults" ? "" : $p[3]);
	if (($j = &indexof("noauto", @o)) >= 0) {
		# filesytem is not mounted at boot
		splice(@o, $j, 1);
		$rv[$i]->[5] = "no";
		}
	$rv[$i]->[3] = (@o ? join(',' , @o) : "-");
	$rv[$i]->[4] = (@p >= 5 ? $p[5] : 0);
	$i++;
	}
close(FSTAB);
return @rv;
}


# create_mount(directory, device, type, options, fsck_order, mount_at_boot)
# Add a new entry to the fstab file, old or new automounter file
sub create_mount
{
local(@mlist, @amd, $_); local($opts);

# Adding a normal mount to the fstab file
&open_tempfile(FSTAB, ">>$config{'fstab_file'}");
&print_tempfile(FSTAB, "$_[1]  $_[0]  $_[2]");
$opts = $_[3] eq "-" ? "" : $_[3];
if ($_[5] eq "no") {
	$opts = join(',' , (split(/,/ , $opts) , "noauto"));
	}
if ($opts eq "") { &print_tempfile(FSTAB, "  defaults"); }
else { &print_tempfile(FSTAB, "  $opts"); }
&print_tempfile(FSTAB, "  0  ");
&print_tempfile(FSTAB, $_[4] eq "-" ? "0\n" : "$_[4]\n");
&close_tempfile(FSTAB);
}


# change_mount(num, directory, device, type, options, fsck_order, mount_at_boot)
# Change an existing permanent mount
sub change_mount
{
local($i, @fstab, $line, $opts, $j, @amd);
$i = 0;

# Update fstab file
open(FSTAB, $config{'fstab_file'});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, ">$config{'fstab_file'}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $i++ == $_[0]) {
		# Found the line to replace
		&print_tempfile(FSTAB, "$_[2]  $_[1]  $_[3]");
		$opts = $_[4] eq "-" ? "" : $_[4];
		if ($_[6] eq "no") {
			$opts = join(',' , (split(/,/ , $opts) , "noauto"));
			}
		if ($opts eq "") { &print_tempfile(FSTAB, "  defaults"); }
		else { &print_tempfile(FSTAB, "  $opts"); }
		&print_tempfile(FSTAB, "  0  ");
		&print_tempfile(FSTAB, $_[5] eq "-" ? "0\n" : "$_[5]\n");
		}
	else {
		&print_tempfile(FSTAB, $_,"\n");
		}
	}
&close_tempfile(FSTAB);
}


# delete_mount(index)
# Delete an existing permanent mount
sub delete_mount
{
local($i, @fstab, $line, $opts, $j, @amd);
$i = 0;

# Update fstab file
open(FSTAB, $config{'fstab_file'});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, ">$config{'fstab_file'}");
foreach (@fstab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line !~ /\S/ || $i++ != $_[0]) {
		# Don't delete this line
		&print_tempfile(FSTAB, $_,"\n");
		}
	}
&close_tempfile(FSTAB);
}


# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
# Under OpenBSD, there seems to be no way to get additional mount options
# used by filesystems like NFS etc. Even getting the full details of mounted
# filesystems requires C code! So we have to call a specially-written external
# program to get the mount list
sub list_mounted
{
# get the list of mounted filesystems
local(@rv, $_);
local $cmd = $uname_release =~ /^[3456789]\.[0-9]/ ? "netbsd-mounts-3" :
	     $uname_release =~ /^2\.[0-9]/ ? "netbsd-mounts-2" :
					     "netbsd-mounts";
&compile_program($cmd);
open(CMD, "$module_config_directory/$cmd |");
while(<CMD>) {
	local @p = split(/\t/, $_);
	if ($p[2] eq "procfs" || $p[1] eq "procfs") { $p[1] = $p[2] = "proc"; }
	push(@rv, \@p);
	}
close(CMD);

# add output from swapinfo
&open_execute_command(SWAP, "swapinfo", 1, 1);
while(<SWAP>) {
	if (/^(\/\S+)\s+\d+\s+\d+/) {
		push(@rv, [ "swap", $1, "swap", "-" ]);
		}
	}
close(SWAP);
return @rv;
}


# mount_dir(directory, device, type, options)
# Mount a new directory from some device, with some options. Returns 0 if ok,
# or an error string if failed
sub mount_dir
{
local($out, $opts, $shar, %options, %smbopts);
if ($_[2] eq "swap") {
	# Use swapon to add the swap space..
	$out = &backquote_logged("swapon $_[1] 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	}
else {
	# some disk-based filesystem
	$opts = $_[3] eq "-" ? "" : "-o \"$_[3]\"";
	$opts = join(',', grep { !/quota/ } split(/,/, $opts));
	$out = &backquote_logged("mount -t $_[2] $opts $_[1] $_[0] 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	}
return 0;
}


# unmount_dir(directory, device, type)
# Unmount a directory that is currently mounted. Returns 0 if ok,
# or an error string if failed
sub unmount_dir
{
local($out, %smbopts, $dir);
if ($_[2] eq "swap") {
	# Not possible!
	&error("Swap space cannot be removed");
	}
else {
	$out = &backquote_logged("umount $_[0] 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	}
return 0;
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
elsif ($_[0] eq "ffs")
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
local @rv = ("ffs", "nfs", "cd9660", "msdos", "swap");
push(@rv, "ext2fs") if (&has_command("mount_ext2fs"));
return @rv;
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ffs", "NetBSD Unix Filesystem",
	  "nfs","Network Filesystem",
	  "cd9660","ISO9660 CD-ROM",
	  "msdos","MS-DOS Filesystem",
	  "ext2fs","Linux Filesystem",
	  "swap","Virtual Memory",
	  "proc","Process Image Filesystem");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return $_[0] eq "nfs";
}


# generate_location(type, location)
# Output HTML for editing the mount location of some filesystem.
sub generate_location
{
local ($type, $loc) = @_;
if ($type eq "nfs") {
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
else {
	local $msg;
        if ($type eq "swap") {
                # Swap file or device
		$msg = $text{'linux_swapfile'};
                }
        else {
                # Disk-based filesystem
                $msg = &fstype_name($type);
                }
	local ($disk_dev, $ide_t, $ide_s, $ide_p, $scsi_t, $scsi_s, $scsi_p);
	if ($loc =~ /^\/dev\/wd(\d)s(\d)([a-z]*)$/) {
		$disk_dev = 0; $ide_t = $1; $ide_s = $2; $ide_p = $3;
		}
	elsif ($loc =~ /^\/dev\/sd(\d)s(\d)([a-z]*)$/) {
		$disk_dev = 1; $scsi_t = $1; $scsi_s = $2; $scsi_p = $3;
		}
	else { $disk_dev = 2; }

        print &ui_table_row($msg,
                &ui_radio_table("disk_dev", $disk_dev,
                  [ [ 0, $text{'freebsd_ide'},
                      $text{'freebsd_device'}." ".
                        &ui_textbox("ide_t", $ide_t, 4)." ".
                      $text{'freebsd_slice'}." ".
                        &ui_textbox("ide_s", $ide_s, 4)." ".
                      $text{'freebsd_part'}." ".
                        &ui_textbox("ide_p", $ide_p, 4) ],
                    [ 1, $text{'freebsd_scsi'},
                      $text{'freebsd_device'}." ".
                        &ui_textbox("scsi_t", $scsi_t, 4)." ".
                      $text{'freebsd_slice'}." ".
                        &ui_textbox("scsi_s", $scsi_s, 4)." ".
                      $text{'freebsd_part'}." ".
                        &ui_textbox("scsi_p", $scsi_p, 4) ],
                    [ 2, $text{'freebsd_other'},
                      &ui_textbox("dev_path", $disk_dev == 2 ? $loc : "", 40).
                      " ".&file_chooser_button("dev_path", 0) ] ]));
	}
}


# generate_options(type, newmount)
# Output HTML for editing mount options for a particular filesystem 
# under this OS
sub generate_options
{
if ($_[0] ne "swap") {
	# These options are common to all filesystems
	print "<tr> <td><b>Read-only?</b></td>\n";
	printf "<td nowrap><input type=radio name=bsd_ro value=1 %s> Yes\n",
		defined($options{"rdonly"}) || defined($options{"ro"})
			? "checked" : "";
	printf "<input type=radio name=bsd_ro value=0 %s> No</td>\n",
		defined($options{"rdonly"}) || defined($options{"ro"})
			? "" : "checked";

	print "<td><b>Buffer writes to filesystem?</b></td>\n";
	printf"<td nowrap><input type=radio name=bsd_sync value=0 %s> Yes\n",
		defined($options{"sync"}) ? "" : "checked";
	printf "<input type=radio name=bsd_sync value=1 %s> No</td> </tr>\n",
		defined($options{"sync"}) ? "checked" : "";

	print "<tr> <td><b>Allow device files?</b></td>\n";
	printf "<td nowrap><input type=radio name=bsd_nodev value=0 %s> Yes\n",
		defined($options{"nodev"}) ? "" : "checked";
	printf "<input type=radio name=bsd_nodev value=1 %s> No</td>\n",
		defined($options{"nodev"}) ? "checked" : "";

	print "<td><b>Allow execution of binaries?</b></td>\n";
	printf"<td nowrap><input type=radio name=bsd_noexec value=0 %s> Yes\n",
		defined($options{"noexec"}) ? "" : "checked";
	printf "<input type=radio name=bsd_noexec value=1 %s> No</td> </tr>\n",
		defined($options{"noexec"}) ? "checked" : "";

	print "<tr> <td><b>Disallow setuid programs?</b></td>\n";
	printf "<td nowrap><input type=radio name=bsd_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=bsd_nosuid value=0 %s> No</td>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<td><b>Update access times?</b></td>\n";
	printf"<td nowrap><input type=radio name=bsd_noatime value=0 %s> Yes\n",
		defined($options{"noatime"}) ? "" : "checked";
	printf "<input type=radio name=bsd_noatime value=1 %s> No</td> </tr>\n",
		defined($options{"noatime"}) ? "checked" : "";

	}

if ($_[0] eq "ffs") {
	# FFS filesystems support quotas
	print "<tr> <td><b>User quotas at boot</b></td> <td colspan=3>\n";
	printf "<input type=radio name=ffs_userquota value=0 %s> Disabled\n",
		defined($options{'userquota'}) ? "" : "checked";
	printf "<input type=radio name=ffs_userquota value=1 %s> Enabled\n",
		defined($options{'userquota'}) && $options{'userquota'} eq ""
			? "checked" : "";
	printf "<input type=radio name=ffs_userquota value=2 %s>\n",
		$options{'userquota'} ? "checked" : "";
	print "Enabled, use file\n";
	printf "<input name=ffs_userquota_file size=30 value=\"%s\">\n",
		$options{'userquota'};
	print "</td> </tr>\n";
		
	print "<tr> <td><b>Group quotas at boot</b></td> <td colspan=3>\n";
	printf "<input type=radio name=ffs_groupquota value=0 %s> Disabled\n",
		defined($options{'groupquota'}) ? "" : "checked";
	printf "<input type=radio name=ffs_groupquota value=1 %s> Enabled\n",
		defined($options{'groupquota'}) && $options{'groupquota'} eq ""
			? "checked" : "";
	printf "<input type=radio name=ffs_groupquota value=2 %s>\n",
		$options{'groupquota'} ? "checked" : "";
	print "Enabled, use file\n";
	printf "<input name=ffs_groupquota_file size=30 value=\"%s\">\n",
		$options{'groupquota'};
	print "</td> </tr>\n";
	}
elsif ($_[0] eq "nfs") {
	# NFS filesystems have lots more options
	print "<tr> <td><b>Retry mounts in background?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_b value=1 %s> Yes\n",
		defined($options{"-b"}) ? "checked" : "";
	printf "<input type=radio name=nfs_b value=0 %s> No</td>\n",
		defined($options{"-b"}) ? "" : "checked";

	print "<td><b>Return error on timeouts?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_s value=1 %s> Yes\n",
		defined($options{"-s"}) ? "checked" : "";
	printf "<input type=radio name=nfs_s value=0 %s> No</td> </tr>\n",
		defined($options{"-s"}) ? "" : "checked";

	print "<tr> <td><b>Timeout</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_t_def value=1 %s> Default\n",
		defined($options{"-t"}) ? "" : "checked";
	printf "<input type=radio name=nfs_t_def value=0 %s>\n",
		defined($options{"-t"}) ? "checked" : "";
	printf "<input size=5 name=nfs_t value=\"$options{'-t'}\"></td>\n";

	print "<td><b>Number of Retransmissions</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_x_def value=1 %s> Default\n",
		defined($options{"-x"}) ? "" : "checked";
	printf "<input type=radio name=nfs_x_def value=0 %s>\n",
		defined($options{"-x"}) ? "checked" : "";
	print "<input size=5 name=nfs_x value=\"$options{'-x'}\"></td> </tr>\n";

	print "<tr> <td><b>NFS version</b></td> <td nowrap>\n";
	local $v = defined($options{"-2"}) ? 2 :
		   defined($options{"-3"}) ? 3 : 0;
	printf "<input type=radio name=nfs_ver value=0 %s> Auto\n",
		$v ? "" : "checked";
	printf "<input type=radio name=nfs_ver value=2 %s> V2\n",
		$v == 2 ? "checked" : "";
	printf "<input type=radio name=nfs_ver value=3 %s> V3</td>\n",
		$v == 3 ? "checked" : "";

	print "<td><b>Mount retries</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_r_def value=1 %s> Default\n",
		defined($options{"-R"}) ? "" : "checked";
	printf "<input type=radio name=nfs_r_def value=0 %s>\n",
		defined($options{"-R"}) ? "checked" : "";
	print "<input size=5 name=nfs_r value=\"$options{'-R'}\"></td> </tr>\n";

	print "<tr> <td><b>Read-ahead blocks</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_a_def value=1 %s> Default\n",
		defined($options{"-a"}) ? "" : "checked";
	printf "<input type=radio name=nfs_a_def value=0 %s>\n",
		defined($options{"-a"}) ? "checked" : "";
	print "<input size=5 name=nfs_a value=\"$options{'-a'}\"></td> </tr>\n";

	print "<tr> <td><b>RPC Protocol</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_t2 value=1 %s> TCP\n",
		defined($options{"-T"}) ? "checked" : "";
	printf "<input type=radio name=nfs_t2 value=0 %s> UDP</td> </tr>\n",
		defined($options{"-T"}) ? "" : "checked";
	}
elsif ($_[0] eq "msdos"){
	# MS-DOS filesystems options deal with filling in
	# missing unix functionality
	print "<tr> <td><b>User files are owned by</b></td>\n";
	printf "<td><input name=msdos_u size=8 value=\"%s\">\n",
		defined($options{"-u"}) ? getpwuid($options{"-u"}) : "";
	print &user_chooser_button("msdos_u", 0),"</td>\n";

	print "<td><b>Group files are owned by</b></td>\n";
	printf "<td><input name=msdos_g size=8 value=\"%s\">\n",
		defined($options{"-g"}) ? getgrgid($options{"-g"}) : "";
	print &group_chooser_button("msdos_g", 0),"</td>\n";

	print "<tr> <td><b>File permissions mask</b></td>\n";
	printf "<td><input type=radio name=msdos_m_def value=1 %s> Default\n",
		defined($options{"-m"}) ? "" : "checked";
	printf "<input type=radio name=msdos_m_def value=0 %s>\n",
		defined($options{"-m"}) ? "checked" : "";
	print "<input size=5 name=msdos_m value=\"$options{'-m'}\"></td>\n";
	}
elsif ($_[0] eq "cd9660") {
	# CDROM filesystem
	print "<tr> <td><b>Ignore Unix Attributes?</b></td>\n";
	printf "<td><input type=radio name=cd9660_r value=1 %s> Yes\n",
		defined($options{"-r"}) ? "checked" : "";
	printf "<input type=radio name=cd9660_r value=0 %s> No</td>\n",
		defined($options{"-r"}) ? "" : "checked";

	print "<td><b>Show version numbers?</b></td>\n";
	printf "<td><input type=radio name=cd9660_g value=1 %s> Yes\n",
		defined($options{"-g"}) ? "checked" : "";
	printf "<input type=radio name=cd9660_g value=0 %s> No</td> </tr>\n",
		defined($options{"-g"}) ? "" : "checked";

	print "<tr> <td><b>Use extended attributes?</b></td>\n";
	printf "<td><input type=radio name=cd9660_e value=1 %s> Yes\n",
		defined($options{"-e"}) ? "checked" : "";
	printf "<input type=radio name=cd9660_e value=0 %s> No</td> </tr>\n",
		defined($options{"-e"}) ? "" : "checked";
	}
elsif ($_[0] eq "swap") {
	# Swap has no options..
	print "<tr> <td><i>No Options Available</i></td> </tr>\n";
	}
}


# check_location(type)
# Parse and check inputs from %in, calling &error() if something is wrong.
# Returns the location string for storing in the fstab file
sub check_location
{
if ($_[0] eq "nfs") {
	local($out, $temp, $mout, $dirlist);

	if ($config{'nfs_check'}) {
		# Use ping and showmount to see if the host exists and is up
		if ($in{nfs_host} !~ /^\S+$/) {
			&error("'$in{nfs_host}' is not a valid hostname");
			}
		$out = &backquote_command("ping -c 1 '$in{nfs_host}' 2>&1");
		if ($out =~ /unknown host/i) {
			&error("The host '$in{nfs_host}' does not exist");
			}
		elsif ($out =~ /100\% packet loss/) {
			&error("The host '$in{nfs_host}' is down");
			}
		$out = &backquote_command("showmount -e '$in{nfs_host}' 2>&1");
		if ($out =~ /Unable to receive/) {
			&error("The host '$in{nfs_host}' does not support NFS");
			}
		elsif ($?) {
			&error("Failed to get mount list : $out");
			}
		}

	# Validate directory name
	foreach (split(/\n/, $out)) {
		if (/^(\/\S+)/) { $dirlist .= "$1\n"; }
		}
	if ($in{nfs_dir} !~ /^\/\S+$/) {
		&error("'$in{nfs_dir}' is not a valid directory name. The ".
		       "available directories on $in{nfs_host} are:".
		       "<pre>$dirlist</pre>");
		}

	# Try a test mount to see if filesystem is available
	$temp = &transname();
	&make_dir($temp, 0755);
	$mout = &backquote_command("mount $in{nfs_host}:$in{nfs_dir} $temp 2>&1");
	if ($mout =~ /No such file or directory/) {
		&error("The directory '$in{nfs_dir}' does not exist on the ".
		       "host $in{nfs_host}. The available directories are:".
		       "<pre>$dirlist</pre>");
		}
	elsif ($mout =~ /Permission denied/) {
		&error("This host is not allowed to mount the directory ".
		       "$in{nfs_dir} from $in{nfs_host}");
		}
	elsif ($?) {
		&error("NFS Error - $mout");
		}
	# It worked! unmount
	&execute_command("umount $temp");
	&unlink_file($temp);
	return "$in{nfs_host}:$in{nfs_dir}";
	}
else {
	# This is some kind of disk-based filesystem.. get the device name
	if ($in{'disk_dev'} == 0) {
		$in{'ide_t'} =~ /^\d+$/ ||
			&error("'$in{ide_t}' is not a valid device number");
		$in{'ide_s'} =~ /^\d+$/ ||
			&error("'$in{ide_s}' is not a valid slice number");
		$in{'ide_p'} =~ /^[a-z]*$/ ||
			&error("'$in{ide_p}' is not a valid partition letter");
		$dv = "/dev/wd$in{ide_t}s$in{ide_s}$in{ide_p}";
		}
	elsif ($in{'disk_dev'} == 1) {
		$in{'scsi_t'} =~ /^\d+$/ ||
			&error("'$in{scsi_t}' is not a valid device number");
		$in{'scsi_s'} =~ /^\d+$/ ||
			&error("'$in{scsi_s}' is not a valid slice number");
		$in{'scsi_p'} =~ /^[a-z]*$/ ||
			&error("'$in{scsi_p}' is not a valid partition letter");
		$dv = "/dev/sd$in{scsi_t}s$in{scsi_s}$in{scsi_p}";
		}
	else {
		$dv = $in{'dev_path'};
		}

	# If the device entered is a symlink, follow it
	if ($dvlink = readlink($dv)) {
		if ($dvlink =~ /^\//) { $dv = $dvlink; }
		else {	$dv =~ /^(.*\/)[^\/]+$/;
			$dv = $1.$dvlink;
			}
		}

	# Check if the device actually exists and uses the right filesystem
	(-r $dv) || &error("The device file '$dv' does not exist");
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
if ($_[0] ne "swap") {
	delete($options{"ro"}); delete($options{"rw"});
	delete($options{"rdonly"});
	if ($in{'bsd_ro'}) { $options{'ro'} = ''; }
	else { $options{'rw'} = ""; }

	delete($options{"sync"}); delete($options{"async"});
	if ($in{'bsd_sync'}) { $options{'sync'} = ''; }

	delete($options{'nodev'});
	if ($in{'bsd_nodev'}) { $options{'nodev'} = ''; }

	delete($options{'noexec'});
	if ($in{'bsd_noexec'}) { $options{'noexec'} = ''; }

	delete($options{'nosuid'});
	if ($in{'bsd_nosuid'}) { $options{'nosuid'} = ''; }

	delete($options{'noatime'});
	if ($in{'bsd_noatime'}) { $options{'noatime'} = ''; }

	}
else {
	# Swap always has the sw option
	$options{'sw'} = "";
	}

if ($_[0] eq "ffs") {
	# Parse FFS quota options
	delete($options{'userquota'}) if ($in{'ffs_userquota'} == 0);
	$options{'userquota'} = "" if ($in{'ffs_userquota'} == 1);
	$options{'userquota'} = $in{'ffs_groupquota_file'}
		if ($in{'ffs_userquota'} == 2);

	delete($options{'groupquota'}) if ($in{'ffs_groupquota'} == 0);
	$options{'groupquota'} = "" if ($in{'ffs_groupquota'} == 1);
	$options{'groupquota'} = $in{'ffs_groupquota_file'}
		if ($in{'ffs_groupquota'} == 2);
	}
elsif ($_[0] eq "nfs") {
	# NFS has a few specific options..
	delete($options{'-b'});
	$options{'-b'} = "" if ($in{'nfs_b'});

	delete($options{'-s'});
	$options{'-s'} = "" if ($in{'nfs_s'});

	delete($options{'-t'});
	$options{'-t'} = $in{'nfs_t'} if (!$in{'nfs_t_def'});

	delete($options{'-x'});
	$options{'-x'} = $in{'nfs_x'} if (!$in{'nfs_x_def'});

	delete($options{'-2'}); delete($options{'-3'});
	$options{'-2'} = "" if ($in{'nfs_ver'} == 2);
	$options{'-3'} = "" if ($in{'nfs_ver'} == 3);

	delete($options{'-R'});
	$options{'-R'} = $in{'nfs_r'} if (!$in{'nfs_r_def'});

	delete($options{'-a'});
	$options{'-a'} = $in{'nfs_a'} if (!$in{'nfs_a_def'});

	delete($options{'-T'});
	$options{'-T'} = "" if ($in{'nfs_t2'});
	}
elsif ($_[0] eq "msdos") {
	# MSDOS options for file ownership/perms
	delete($options{"-u"}); delete($options{"-g"});
	if ($in{'msdos_u'} ne "") { $options{'-u'} = getpwnam($in{'msdos_u'}); }
	if ($in{'msdos_g'} ne "") { $options{'-g'} = getgrnam($in{'msdos_g'}); }

	delete($options{"-m"});
	if (!$in{'msdos_m_def'}) {
		$in{'msdos_m'} =~ /^[0-7]{3}$/ ||
			&error("'$in{'msdos_m'}' is not a valid octal mask");
		$options{'-m'} = $in{'msdos_m'};
		}
	}
elsif ($_[0] eq "cd9660") {
	# Options for iso9660 cd-roms
	delete($options{'-r'});
	$options{'-r'} = "" if ($in{'cd9660_r'});

	delete($options{'-g'});
	$options{'-g'} = "" if ($in{'cd9660_g'});

	delete($options{'-e'});
	$options{'-e'} = "" if ($in{'cd9660_e'});
	}

# Return options string
foreach $k (keys %options) {
	if ($options{$k} eq "") { push(@rv, $k); }
	else { push(@rv, "$k=$options{$k}"); }
	}
return @rv ? join(',' , @rv) : "-";
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
if ($out =~ /broadcast\s+(\S+)\s+/) { return $1; }
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

