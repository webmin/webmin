# freebsd-lib.pl
# Mount table functions for freebsd

$uname_release = &backquote_command("uname -r");
if (&has_command("mount_smbfs")) {
	$smbfs_support = 1;
	$nsmb_conf = "/etc/nsmb.conf";
	}
$ide_device_prefix = $uname_release > 9 ? "ada" : "ad";
&foreign_require("bsdfdisk");

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
	elsif ($p[2] eq "swap") { $p[1] = "swap"; }
	elsif ($p[2] eq "smbfs") {
		# Need to get nsmb.conf options, covert share and extract user
		$p[0] = lc($p[0]);
		local $noptions = &read_nsmb($p[0]);
		local %options;
		&parse_options($p[3]);
		if ($p[0] =~ /^\/\/(\S+)\@(\S+)\/(.*)$/) {
			$p[0] = "\\\\$2\\$3";
			$options{'user'} = $1;
			}
		elsif ($p[0] =~ /\/\/(\S+)\/(.*)$/) {
			$p[0] = "\\\\$1\\$2";
			}
		%options = ( %options, %$noptions );
		$p[3] = &join_options();
		}
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
local(@mlist, @amd, $_, $opts);

&open_tempfile(FSTAB, ">> $config{'fstab_file'}");
&print_mount_line(@_);
&close_tempfile(FSTAB);
}

# print_mount_line(directory, device, type, options, fsck_order, mount_at_boot)
sub print_mount_line
{
if ($_[2] eq "smbfs") {
	# Adding an SMB mount, which needs special handling
	local %options;
	&parse_options("smbfs", $_[3]);
	local $share;
	if ($options{'user'} && $_[1] =~ /^\\\\(.*)\\(.*)$/) {
		$share = "//$options{'user'}\@$1/$2";
		}
	else {
		($share = $_[1]) =~ s/\\/\//g;
		}
	&print_tempfile(FSTAB, "$share  $_[0]  $_[2]");
	local $roptions = &update_nsmb($share, \%options);
	delete($roptions->{'user'});
	$opts = &join_options($_[2], $roptions);
	}
else {
	# Adding a normal mount to the fstab file
	&print_tempfile(FSTAB, "$_[1]  $_[0]  $_[2]");
	$opts = $_[3] eq "-" ? "" : $_[3];
	}
if ($_[5] eq "no") {
	$opts = join(',' , (split(/,/ , $opts) , "noauto"));
	}
if ($opts eq "") {
	&print_tempfile(FSTAB, "  defaults");
	}
else {
	&print_tempfile(FSTAB, "  $opts");
	}
&print_tempfile(FSTAB, "  0  ");
&print_tempfile(FSTAB, $_[4] eq "-" ? "0\n" : "$_[4]\n");
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
	if ($line =~ /\S/ && $i++ == $_[0]) {
		# Found the line to replace
		&print_mount_line(@_[1..$#_]);
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
open(FSTAB, $config{fstab_file});
@fstab = <FSTAB>;
close(FSTAB);
&open_tempfile(FSTAB, "> $config{fstab_file}");
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
# Under FreeBSD, there seems to be no way to get additional mount options
# used by filesystems like NFS etc. Even getting the full details of mounted
# filesystems requires C code! So we have to call a specially-written external
# program to get the mount list
sub list_mounted
{
# get the list of mounted filesystems
local(@rv, $_);
local $cmd = $uname_release =~ /^(\d+)\.[0-9]/ && $1 > 6 ? "freebsd-mounts-7" :
	     $uname_release =~ /^[56]\.[0-9]/ ? "freebsd-mounts-5" :
	     $uname_release =~ /^4\.[0-9]/ ? "freebsd-mounts-4" :
	     $uname_release =~ /^3\.[1-9]/ ? "freebsd-mounts-3" :
				             "freebsd-mounts-2";
&compile_program($cmd, '.*86');
open(CMD, "$module_config_directory/$cmd |");
while(<CMD>) {
	local @p = split(/\t/, $_);
	if ($p[2] eq "procfs" || $p[1] eq "procfs") { $p[1] = $p[2] = "proc"; }
	elsif ($p[2] eq "mfs") { $p[1] =~ s/:.*$//; }
	elsif ($p[2] eq "smbfs") {
		# Need to get nsmb.conf options, covert share and extract user
		$p[1] = lc($p[1]);
		local $noptions = &read_nsmb($p[1]);
		local %options;
		&parse_options($p[3]);
		if ($p[1] =~ /^\/\/(\S+)\@(\S+)\/(.*)$/) {
			$p[1] = "\\\\$2\\$3";
			$options{'user'} = $1;
			}
		elsif ($p[1] =~ /\/\/(\S+)\/(.*)$/) {
			$p[1] = "\\\\$1\\$2";
			}
		%options = ( %options, %$noptions );
		$p[3] = &join_options();
		}
	push(@rv, \@p);
	}
close(CMD);

# add output from swapinfo
local $out;
&execute_command("swapinfo", undef, \$out, undef, 0, 1);
foreach (split(/\n/, $out)) {
	if (/^(\/\S+)\s+\d+\s+\d+/) {
		push(@rv, [ "swap", $1, "swap", "-" ]);
		}
	}
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
elsif ($_[2] eq "smbfs") {
	# Need special handling for SMB mounts
	local %options;
	&parse_options($_[2], $_[3]);
	local $share;
	if ($options{'user'} && $_[1] =~ /^\\\\(.*)\\(.*)$/) {
		$share = "//$options{'user'}\@$1/$2";
		}
	else {
		($share = $_[1]) =~ s/\\/\//g;
		}
	local $roptions = &update_nsmb($share, \%options);
	delete($roptions->{'user'});
	local $opts = &join_options($_[2], $roptions);
	$opts = $opts ne "-" ? " -o $opts" : "";
	&foreign_require("proc");
	local ($fh, $fpid) = &proc::pty_process_exec_logged(
		"mount -t $_[2] $opts $share $_[0]");
	local $got;
	local $rv = &wait_for($fh, "Password:");
	$got .= $wait_for_input;
	if ($rv == 0) {
		print $fh $options{'nsmb_password'},"\n";
		}
	$rv = &wait_for($fh);
	$got .= $wait_for_input;
	close($fh);
	if ($? || $got =~ /failed|error|syserr|usage:/i) { return "<pre>$out</pre>"; }
	}
else {
	# Can use mount command for this filesystem
	$opts = $_[3] eq "-" ? "" :
			"-o ".join(',', grep { !/quota/ } split(/,/, $_[3]));
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
my $out;
&execute_command("df -k ".quotemeta($_[1]), undef, \$out, undef, 0, 1);
if ($out =~ /Mounted on\n\S+\s+(\S+)\s+\S+\s+(\S+)/) {
	return ($1, $2);
	}
else {
	return ( );
	}
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
push(@rv, "smbfs") if ($smbfs_support);
return @rv;
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("ufs", "FreeBSD Unix Filesystem",
	  "nfs", "Network Filesystem",
	  "cd9660", "ISO9660 CD-ROM",
	  "msdos", "MS-DOS Filesystem",
	  "ext2fs", "Linux Filesystem",
	  "ntfs", "Windows NT Filesystem",
	  "swap", "Virtual Memory",
	  "proc", "Process Image Filesystem",
	  "smbfs", "Windows Networking Filesystem");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return $_[0] eq "nfs" || $_[0] eq "smbfs";
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
elsif ($type eq "smbfs") {
	# SMB mount from some server and share
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

	# Generate disk selection options
	my @opts;
	my $found;
	my $sel = &bsdfdisk::partition_select(
		"disk_select", $loc, 3, \$found);
	push(@opts, [ 0, $text{'freebsd_select'}, $sel ]);
	push(@opts, [ 1, $text{'freebsd_other'},
		      &ui_textbox("dev_path", $found ? "" : $loc, 40).
		      " ".&file_chooser_button("dev_path", 0) ]);
	print &ui_table_row($msg,
		&ui_radio_table("disk_dev", $found ? 0 : 1, \@opts));
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

	if ($uname_release =~ /^[34]\./) {
		# FreeBSD 3.x has some more options
		print "<tr> <td><b>Follow symbolic links?</b></td>\n";
		printf "<td nowrap><input type=radio name=bsd_nosymfollow value=0 %s> Yes\n",
			defined($options{"nosymfollow"}) ? "" : "checked";
		printf "<input type=radio name=bsd_nosymfollow value=1 %s> No</td>\n",
			defined($options{"nosymfollow"}) ? "checked" : "";

		print "<td><b>Files inherit group from SUID directories?</b></td>\n";
		printf"<td nowrap><input type=radio name=bsd_suiddir value=1 %s> Yes\n",
			defined($options{"suiddir"}) ? "checked" : "";
		printf "<input type=radio name=bsd_suiddir value=0 %s> No</td> </tr>\n",
			defined($options{"suiddir"}) ? "" : "checked";
		}
	}

if ($_[0] eq "ufs") {
	# UFS filesystems support quotas
	print "<tr> <td><b>User quotas at boot</b></td> <td colspan=3>\n";
	printf "<input type=radio name=ufs_userquota value=0 %s> Disabled\n",
		defined($options{'userquota'}) ? "" : "checked";
	printf "<input type=radio name=ufs_userquota value=1 %s> Enabled\n",
		defined($options{'userquota'}) && $options{'userquota'} eq ""
			? "checked" : "";
	printf "<input type=radio name=ufs_userquota value=2 %s>\n",
		$options{'userquota'} ? "checked" : "";
	print "Enabled, use file\n";
	printf "<input name=ufs_userquota_file size=30 value=\"%s\">\n",
		$options{'userquota'};
	print "</td> </tr>\n";
		
	print "<tr> <td><b>Group quotas at boot</b></td> <td colspan=3>\n";
	printf "<input type=radio name=ufs_groupquota value=0 %s> Disabled\n",
		defined($options{'groupquota'}) ? "" : "checked";
	printf "<input type=radio name=ufs_groupquota value=1 %s> Enabled\n",
		defined($options{'groupquota'}) && $options{'groupquota'} eq ""
			? "checked" : "";
	printf "<input type=radio name=ufs_groupquota value=2 %s>\n",
		$options{'groupquota'} ? "checked" : "";
	print "Enabled, use file\n";
	printf "<input name=ufs_groupquota_file size=30 value=\"%s\">\n",
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
	print "<input size=5 name=nfs_a value=\"$options{'-a'}\"></td>\n";

	print "<td><b>RPC Protocol</b></td>\n";
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
elsif ($_[0] eq "ntfs") {
	# Windows NT filesystem
	print "<tr> <td><b>Display MSDOS 8.3 filenames?</b></td>\n";
	printf "<td><input type=radio name=ntfs_a value=1 %s> Yes\n",
		defined($options{"-a"}) ? "checked" : "";
	printf "<input type=radio name=ntfs_a value=0 %s> No</td>\n",
		defined($options{"-a"}) ? "" : "checked";

	print "<td><b>Case sensitive filenames?</b></td>\n";
	printf "<td><input type=radio name=ntfs_i value=0 %s> Yes\n",
		defined($options{"-i"}) ? "" : "checked";
	printf "<input type=radio name=ntfs_i value=1 %s> No</td> </tr>\n",
		defined($options{"-i"}) ? "checked" : "";

	print "<tr> <td><b>User files are owned by</b></td>\n";
	printf "<td><input type=radio name=ntfs_u_def value=1 %s> Default\n",
		defined($options{"-u"}) ? "" : "checked";
	printf "<input type=radio name=ntfs_u_def value=0 %s>\n",
		defined($options{"-u"}) ? "checked" : "";
	printf "<input name=ntfs_u size=8 value='%s'> %s</td>\n",
		defined($options{"-u"}) ? scalar(getpwuid($options{"-u"})) : "",
		&user_chooser_button("ntfs_u");

	print "<td><b>Group files are owned by</b></td>\n";
	printf "<td><input type=radio name=ntfs_g_def value=1 %s> Default\n",
		defined($options{"-u"}) ? "" : "checked";
	printf "<input type=radio name=ntfs_g_def value=0 %s>\n",
		defined($options{"-u"}) ? "checked" : "";
	printf "<input name=ntfs_g size=8 value='%s'> %s</td> </tr>\n",
		defined($options{"-g"}) ? scalar(getgrgid($options{"-g"})) : "",
		&group_chooser_button("ntfs_g");
	}
elsif ($_[0] eq "swap") {
	# Swap has no options..
	print "<tr> <td><i>No Options Available</i></td> </tr>\n";
	}
elsif ($_[0] eq "smbfs") {
	# SMBFS has some special options
	print "<tr> <td><b>$text{'linux_username'}</b></td>\n";
	printf "<td><input name=smbfs_user size=15 value=\"%s\"></td>\n",
		$options{"user"};

	print "<td><b>$text{'linux_password'}</b></td>\n";
	printf "<td><input type=password name=smbfs_password size=15 value=\"%s\"></td> </tr>\n",
		$options{"nsmb_password"};

	print "<tr> <td><b>$text{'linux_wg'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=smbfs_workgroup_def value=1 %s> $text{'linux_auto'}\n",
		defined($options{"nsmb_workgroup"}) ? "" : "checked";
	printf "<input type=radio name=smbfs_workgroup_def value=0 %s>\n",
		defined($options{"nsmb_workgroup"}) ? "checked" : "";
	print "<input size=10 name=smbfs_workgroup value=\"$options{'nsmb_workgroup'}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'linux_mname'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=smbfs_addr_def value=1 %s> %s\n",
		defined($options{"nsmb_addr"}) ? "" : "checked", $text{'linux_auto'};
	printf "<input type=radio name=smbfs_addr_def value=0 %s>\n",
		defined($options{"nsmb_addr"}) ? "checked" : "";
	print "<input size=30 name=smbfs_addr value=\"$options{'nsmb_addr'}\"></td> </tr>\n";
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
		&execute_command("ping -c 1 '$in{nfs_host}'", undef, \$out, \$out);
		if ($out =~ /unknown host/i) {
			&error("The host '$in{nfs_host}' does not exist");
			}
		elsif ($out =~ /100\% packet loss/) {
			&error("The host '$in{nfs_host}' is down");
			}
		&execute_command("showmount -e '$in{nfs_host}'", undef, \$out, \$out);
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
	&execute_command("mount $in{nfs_host}:$in{nfs_dir} $temp",
			 undef, \$mout, \$mout);
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
elsif ($_[0] eq "smbfs") {
	# A windows server filesystem .. check the server and share
	$in{'smbfs_server'} =~ /\S/ || &error($text{'linux_eserver'});
	$in{'smbfs_share'} =~ /\S/ || &error($text{'linux_eshare'});
	return "\\\\".lc($in{'smbfs_server'})."\\".lc($in{'smbfs_share'});
	}
else {
	# This is some kind of disk-based filesystem.. get the device name
	if ($in{'disk_dev'} == 0) {
		# From menu
		$dv = $in{'disk_select'};
		}
	else {
		# Manually entered
		$dv = $in{'dev_path'};
		$dv =~ /^\// || &error($text{'freebsd_edevpath'});
		}

	# If the device entered is a symlink, follow it
	if ($dvlink = readlink($dv)) {
		if ($dvlink =~ /^\//) { $dv = $dvlink; }
		else {	$dv =~ /^(.*\/)[^\/]+$/;
			$dv = $1.$dvlink;
			}
		}

	# Check if the device actually exists and uses the right filesystem
	(-r $dv) || &error(&text('freebsd_edevfile', $dv));
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

	if ($uname_release =~ /^[34]\./) {
		delete($options{'nosymfollow'});
		$options{'nosymfollow'} = '' if ($in{'bsd_nosymfollow'});

		delete($options{'suiddir'});
		$options{'suiddir'} = '' if ($in{'bsd_suiddir'});
		}
	}
else {
	# Swap always has the sw option
	$options{'sw'} = "";
	}

if ($_[0] eq "ufs") {
	# Parse UFS quota options
	delete($options{'userquota'}) if ($in{'ufs_userquota'} == 0);
	$options{'userquota'} = "" if ($in{'ufs_userquota'} == 1);
	$options{'userquota'} = $in{'ufs_groupquota_file'}
		if ($in{'ufs_userquota'} == 2);

	delete($options{'groupquota'}) if ($in{'ufs_groupquota'} == 0);
	$options{'groupquota'} = "" if ($in{'ufs_groupquota'} == 1);
	$options{'groupquota'} = $in{'ufs_groupquota_file'}
		if ($in{'ufs_groupquota'} == 2);
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
elsif ($_[0] eq "ntfs") {
	delete($options{"-u"}); delete($options{"-g"});
	if ($in{'ntfs_u'} ne "") { $options{'-u'} = getpwnam($in{'ntfs_u'}); }
	if ($in{'ntfs_g'} ne "") { $options{'-g'} = getgrnam($in{'ntfs_g'}); }

	delete($options{"-a"});
	$options{"-a"} = '' if ($in{'ntfs_a'});

	delete($options{"-i"});
	$options{"-i"} = '' if ($in{'ntfs_i'});
	}
elsif ($_[0] eq "smbfs") {
	# Parse SMBFS options
	delete($options{'user'});
	$options{'user'} = $in{'smbfs_user'} if ($in{'smbfs_user'});

	delete($options{'nsmb_password'});
	$options{'nsmb_password'} = $in{'smbfs_password'}
		if ($in{'smbfs_password'});

	delete($options{'nsmb_addr'});
	if (!$in{"smbfs_addr_def"}) {
		&check_ipaddress($in{"smbfs_addr"}) ||
			&error($text{'freebsd_eaddr'});
		$options{'nsmb_addr'} = $in{"smbfs_addr"};
		}

	delete($options{'nsmb_workgroup'});
	if (!$in{"smbfs_workgroup_def"}) {
		$in{"smbfs_workgroup"} =~ /^\S+$/ ||
			&error($text{'freebsd_eworkgroup'});
		$options{'nsmb_workgroup'} = $in{"smbfs_workgroup"};
		}
	}

# Return options string
return &join_options();
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
&execute_command("showmount -e ".quotemeta($_[0]), undef, \$out, \$out, 0, 1);
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
&execute_command("ifconfig -a", undef, \$out, \$out, 0, 1);
if ($out =~ /broadcast\s+(\S+)\s+/) { return $1; }
return "255.255.255.255";
}

sub device_name
{
my ($dev) = @_;
return &bsdfdisk::partition_description($dev);
}

sub files_to_lock
{
return ( $config{'fstab_file'}, $nsmb_conf );
}

# get_nsmb_conf(server, share, user)
# Finds a single nsmb.conf section
sub get_nsmb_conf
{
local $conf;
local $insection = 0;
local $lnum = 0;
open(CONF, $nsmb_conf);
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^\s*\[([^:]+):([^:]+):([^:]+)\]/ &&
	    lc($1) eq lc($_[0]) && lc($2) eq lc($_[2]) && lc($3) eq lc($_[1])) {
		# Start of section
		$insection = 1;
		$conf = { 'line' => $lnum,
			  'eline' => $lnum,
			  'server' => lc($_[0]),
			  'user' => lc($_[2]),
			  'share' => lc($_[1]) };
		}
	elsif (/^\s*\[.*\]/) {
		# Start of another section
		$insection = 0;
		}
	elsif (/^\s*(\S+)\s*=\s*(\S+)/ && $insection) {
		$conf->{'values'}->{lc($1)} = $2;
		$conf->{'eline'} = $lnum;
		}
	$lnum++;
	}
close(CONF);
return $conf;
}

# save_nsmb_conf(&conf)
# Updates or creates a single nsmb.conf section
sub save_nsmb_conf
{
local $lref = &read_file_lines($nsmb_conf);
local @lines = ( "[$_[0]->{'server'}:$_[0]->{'user'}:$_[0]->{'share'}]" );
foreach $k (keys %{$_[0]->{'values'}}) {
	push(@lines, $k."=".$_[0]->{'values'}->{$k});
	}
if (defined($_[0]->{'line'})) {
	# Modifying
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       @lines);
	}
else {
	# Adding
	push(@$lref, @lines);
	}
&flush_file_lines();
}

# update_nsmb(share, &options)
sub update_nsmb
{
local ($server, $share, $user);
if ($_[0] =~ /^[\\\/]{2}(\S+)\@(\S+)[\\\/](\S+)$/) {
	($user, $server, $share) = ($1, $2, $3);
	}
elsif ($_[0] =~ /^[\\\/]{2}(\S+)[\\\/](\S+)$/) {
	($user, $server, $share) = ("root", $1, $2);
	}
else {
	&error("Invalid share $_[0]");
	}
local $conf = &get_nsmb_conf($server, $share, $user);
$conf ||= { "server" => $server,
	    "share" => $share,
	    "user" => $user };
$conf->{'values'} = { };
local %others;
foreach $k (keys %{$_[1]}) {
	if ($k =~ /^nsmb_(.*)$/) {
		$conf->{'values'}->{$1} = $_[1]->{$k};
		}
	else {
		$others{$k} = $_[1]->{$k};
		}
	}
&save_nsmb_conf($conf);
return \%others;
}

# read_nsmb(share)
# Returns a hash reference containing options for some share
sub read_nsmb
{
local ($server, $share, $user);
if ($_[0] =~ /^[\\\/]{2}(\S+)\@(\S+)[\\\/](\S+)$/) {
	($user, $server, $share) = ($1, $2, $3);
	}
elsif ($_[0] =~ /^[\\\/]{2}(\S+)[\\\/](\S+)$/) {
	($user, $server, $share) = ("root", $1, $2);
	}
else {
	&error("Invalid share $_[0]");
	}
local $conf = &get_nsmb_conf($server, $share, $user);
if ($conf) {
	local (%rv, $k);
	foreach $k (keys %{$conf->{'values'}}) {
		$rv{"nsmb_".$k} = $conf->{'values'}->{$k};
		}
	return \%rv;
	}
return undef;
}

1;

