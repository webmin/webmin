# hpux-lib.pl
# Filesystem functions for HP-UX (works for me on 10.xx and 11.00)

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
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[2] eq "ignore") { next; }
	if ($p[2] eq "swap") { $p[1] = "swap"; }
	$rv[$i++] = [ $p[1], $p[0], $p[2], $p[3], $p[5], "yes" ];
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

return @rv;
}


# create_mount(directory, device, type, options, fsck_order, mount_at_boot)
# Add a new entry to the fstab file, and return the index of the new entry
sub create_mount
{
local($len, @mlist, $fsck, $dir);
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
        if ($_[4] eq "-") { 
		$fsck = "0";
		}
        else {
		$fsck = $_[4];
		}
	&open_tempfile(FSTAB, ">> $config{fstab_file}");
	&print_tempfile(FSTAB, "$_[1] $_[0] $_[2] $_[3] 0 $fsck\n");
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
	else {
		&print_tempfile(FSTAB, $_,"\n");
		}
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
	else {
		&print_tempfile(AUTOTAB, $_,"\n");
		}
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
	        if ($_[5] eq "-") {
       	        	$fsck = "0";
                	}
        	else {
                	$fsck = $_[5];
                	}
		# Found the line to replace
		&print_tempfile(FSTAB, "$_[2] $_[1] $_[3] $_[4] 0 $fsck\n");
		}
	else {
		&print_tempfile(FSTAB, $_,"\n");
		}
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
	else {
		&print_tempfile(AUTOTAB, $_,"\n");
		}
	}
&close_tempfile(AUTOTAB);
}


# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form: directory device type options
# For swap files, the directory will be 'swap'
sub list_mounted
{
local(@rv, @p, $_, $i, $r);
&open_execute_command(SWAP, "swapinfo -a", 1, 1);
while(<SWAP>) {
	if (/^dev\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) { push(@rv, [ "swap", $8, "swap", "pri=$7" ]); }
	}
close(SWAP);
&open_tempfile(MNTTAB, "/etc/mnttab");
while(<MNTTAB>) {
	s/#.*$//g; if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	if ($p[2] eq "ignore") { next; }
	push(@rv, [ $p[1], $p[0], $p[2], $p[3] ]);
	}
close(MNTTAB);
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
        local(%options, $opts);
        &parse_options("swap", $_[3]);
        if (defined($options{"pri"})) {
		$opts = "-p $options{'pri'}";
		}
	$out = &backquote_logged("swapon $opts $_[1] 2>&1");
	if ($? && !($out =~ /already enabled for paging/)) { return $out; }
	}
else {
	$opts = $_[3] eq "-" ? "" : "-o \"$_[3]\"";
	$out = &backquote_logged("mount -F $_[2] $opts -- $_[1] $_[0] 2>&1");
	if ($?) { return $out; }
	}
return 0;
}


# unmount_dir(directory, device, type)
# Unmount a directory (or swap device) that is currently mounted. Returns 0 if
# ok, or an error string if failed
sub unmount_dir
{
if ($_[0] eq "swap") {
        # Not possible!
        &error("Swap space cannot be removed");
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
if ($_[0] eq "swap") {
	return ();
	}
my $out;
&execute_command("bdf ".quotemeta($_[1]), undef, \$out, \$out, 0, 1);
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
return ("hfs", "vxfs", "swap", "cdfs", "nfs", "lofs");
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("hfs","HP Unix Filesystem",
	  "vxfs","HP Journaled Unix Filesystem",
	  "nfs","Network Filesystem",
	  "cdfs","ISO9660 CD-ROM",
	  "lofs","Loopback Filesystem",
	  "swapfs","Filesystem Swap Space",
	  "swap","Virtual Memory",
	  "autofs","Automounter Filesystem");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# mount_modes(type)
# Given a filesystem type, returns 4 numbers that determine how the file
# system can be mounted, and whether it can be fsck'd
#  0 - cannot be permanently recorded
#  1 - can be permanently recorded, and is always mounted at boot
#  2 - can be permanently recorded, and may or may not be mounted at boot
# The second is:
#  0 - mount is always permanent => mounted when saved
#  1 - doesn't have to be permanent
# The third is:
#  0 - cannot be fsck'd at boot time
#  1 - can be be fsck'd at boot time
# The fourth is:
#  0 - can be unmounted
#  1 - cannot be unmounted
sub mount_modes
{
if ($_[0] eq "hfs" || $_[0] eq "vxfs") {
	return (1, 1, 1, 0);
	}
elsif ($_[0] eq "swap") {
	return (1, 1, 0, 0);
	}
else { return (1, 1, 0, 0); }
}


# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return ($_[0] eq "nfs" || $_[0] eq "lofs");
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
elsif ($type eq "hfs") {
	# Mounted from a normal disk, LVM device or from
	# somewhere else
	local ($hfs_dev, $scsi_c, $scsi_t, $scsi_d, $scsi_s,
	       $scsi_vg, $scsi_lv, $scsi_path);
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$hfs_dev = 0;
		$scsi_c = $1; $scsi_t = $2; $scsi_d = $3; $scsi_s = $4;
		}
	elsif ($loc eq "") {
		$hfs_dev = 0; $scsi_c = $scsi_t = $scsi_s = $scsi_d = 0;
		}
	elsif ($loc =~ /^\/dev\/vg([0-9]+)\/(\S+)/) {
		$hfs_dev = 1; $scsi_vg = $1; $scsi_lv = $2;
		}
	else {
		$hfs_dev = 2; $scsi_path = $loc;
		}
	print &ui_table_row($text{'solaris_hfs'},
	    &ui_radio_table("hfs_dev", $hfs_dev,
		[ [ 0, $text{'freebsd_scsi'},
		    $text{'solaris_ctrlr'}." ".
		      &ui_textbox("hfs_c", $scsi_c, 4)." ".
		    $text{'solaris_target'}." ".
		      &ui_textbox("hfs_t", $scsi_t, 4)." ".
		    $text{'solaris_unit'}." ".
		      &ui_textbox("hfs_d", $scsi_d, 4)." ".
		    $text{'solaris_part'}." ".
		      &ui_textbox("hfs_s", $scsi_s, 4) ],
		  [ 1, $text{'solaris_lvm'},
		    $text{'solaris_vg'}." ".
		      &ui_textbox("hfs_vg", $scsi_vg, 4)." ".
		    $text{'solaris_lv'}." ".
		      &ui_textbox("hfs_lv", $scsi_lv, 20) ],
		  [ 2, $text{'solaris_file'},
		    &ui_textbox("hfs_path", $scsi_path, 40)." ".
		      &file_chooser_button("hfs_path", 0) ] ]));
	}
elsif ($type eq "vxfs") {
	# Mounted from a normal disk, LVM device or from
	# somewhere else
	local ($jfs_dev, $scsi_c, $scsi_t, $scsi_d, $scsi_s,
	       $scsi_vg, $scsi_lv, $scsi_path);
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$jfs_dev = 0;
		$scsi_c = $1; $scsi_t = $2; $scsi_d = $3; $scsi_s = $4;
		}
	elsif ($loc eq "") {
		$jfs_dev = 0; $scsi_c = $scsi_t = $scsi_s = $scsi_d = 0;
		}
	elsif ($loc =~ /^\/dev\/vg([0-9]+)\/(\S+)/) {
		$jfs_dev = 1; $scsi_vg = $1; $scsi_lv = $2;
		}
	else {
		$jfs_dev = 2; $scsi_path = $loc;
		}
	print &ui_table_row($text{'solaris_vxfs'},
	    &ui_radio_table("jfs_dev", $jfs_dev,
		[ [ 0, $text{'freebsd_scsi'},
		    $text{'solaris_ctrlr'}." ".
		      &ui_textbox("jfs_c", $scsi_c, 4)." ".
		    $text{'solaris_target'}." ".
		      &ui_textbox("jfs_t", $scsi_t, 4)." ".
		    $text{'solaris_unit'}." ".
		      &ui_textbox("jfs_d", $scsi_d, 4)." ".
		    $text{'solaris_part'}." ".
		      &ui_textbox("jfs_s", $scsi_s, 4) ],
		  [ 1, $text{'solaris_lvm'},
		    $text{'solaris_vg'}." ".
		      &ui_textbox("jfs_vg", $scsi_vg, 4)." ".
		    $text{'solaris_lv'}." ".
		      &ui_textbox("jfs_lv", $scsi_lv, 20) ],
		  [ 2, $text{'solaris_file'},
		    &ui_textbox("jfs_path", $scsi_path, 40)." ".
		      &file_chooser_button("jfs_path", 0) ] ]));
	}
elsif ($type eq "swap") {
	# Swapping to a disk partition or a file
	local ($swap_dev, $scsi_c, $scsi_t, $scsi_d, $scsi_s,
	       $scsi_vg, $scsi_lv, $scsi_path);
	if ($loc =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)s([0-9]+)$/) {
		$swap_dev = 0;
		$scsi_c = $1; $scsi_t = $2; $scsi_d = $3; $scsi_s = $4;
		}
	elsif ($loc =~ /^\/dev\/vg([0-9]+)\/(\S+)/) {
		$swap_dev = 1; $scsi_vg = $1; $scsi_lv = $2;
		}
	else {
		$swap_dev = 2; $scsi_path = $loc;
		}
	print &ui_table_row($text{'solaris_swapfile'},
	    &ui_radio_table("swap_dev", $swap_dev,
		[ [ 0, $text{'freebsd_scsi'},
		    $text{'solaris_ctrlr'}." ".
		      &ui_textbox("swap_c", $scsi_c, 4)." ".
		    $text{'solaris_target'}." ".
		      &ui_textbox("swap_t", $scsi_t, 4)." ".
		    $text{'solaris_unit'}." ".
		      &ui_textbox("swap_d", $scsi_d, 4)." ".
		    $text{'solaris_part'}." ".
		      &ui_textbox("swap_s", $scsi_s, 4) ],
		  [ 1, $text{'solaris_lvm'},
		    $text{'solaris_vg'}." ".
		      &ui_textbox("swap_vg", $scsi_vg, 4)." ".
		    $text{'solaris_lv'}." ".
		      &ui_textbox("swap_lv", $scsi_lv, 20) ],
		  [ 2, $text{'solaris_file'},
		    &ui_textbox("swap_path", $scsi_path, 40)." ".
		      &file_chooser_button("swap_path", 0) ] ]));
	}
elsif ($type eq "cdfs") {
	# Mounting a SCSI cdrom
	local ($cdfs_dev, $scsi_c, $scsi_t, $scsi_d, $scsi_path);
	if ($_[1] =~ /^\/dev\/dsk\/c([0-9]+)t([0-9]+)d([0-9]+)$/) {
		$cdfs_dev = 0;
		$scsi_c = $1; $scsi_t = $2; $scsi_d = $3;
		}
	else {
		$cdfs_dev = 1;
		$scsi_path = $loc;
		}
	print &ui_table_row($text{'solaris_cdrom'},
		&ui_radio_table("cdfs_dev", $cdfs_dev,
			[ [ 0, $text{'freebsd_scsi'},
			    $text{'solaris_ctrlr'}." ".
			      &ui_textbox("cdfs_c", $scsi_c, 4)." ".
			    $text{'solaris_target'}." ".
			      &ui_textbox("cdfs_t", $scsi_t, 4)." ".
			    $text{'solaris_unit'}." ".
			      &ui_textbox("cdfs_d", $scsi_d, 4) ],
			  [ 1, $text{'solaris_otherdev'},
			    &ui_textbox("cdfs_path", $scsi_path, 40)." ".
			      &file_chooser_button("cdfs_path", 0) ] ]));
	}
elsif ($type eq "lofs") {
	# Mounting some directory to another location
	print &ui_table_row($text{'solaris_orig'},
		&ui_textbox("lofs_src", $loc, 40)." ".
		&file_chooser_button("lofs_src", 1));
	}
elsif ($type eq "swapfs") {
	# Mounting a cached filesystem of some type.. need a location for
	# the source of the mount
	print &ui_table_row($text{'solaris_cache'},
		&ui_textbox("cfs_src", $loc, 40));
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
}


# generate_options(type, newmount)
# Output HTML for editing mount options for a partilcar filesystem 
# under this OS
sub generate_options
{
if ($_[0] eq "nfs") {
	# NFS has many options, not all of which are editable here
	print "<tr> <td><b>Read-Only?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=nfs_ro value=0 %s> No</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>Disallow setuid programs?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=nfs_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<tr> <td><b>Return error on timeouts?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_soft value=1 %s> Yes\n",
		defined($options{"soft"}) ? "checked" : "";
	printf "<input type=radio name=nfs_soft value=0 %s> No</td>\n",
		defined($options{"soft"}) ? "" : "checked";

	print "<td><b>Retry mounts in background?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_bg value=1 %s> Yes\n",
		defined($options{"bg"}) ? "checked" : "";
	printf "<input type=radio name=nfs_bg value=0 %s> No</td> </tr>\n",
		defined($options{"bg"}) ? "" : "checked";

	print "<tr> <td><b>Allow interrupts?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nointr value=0 %s> Yes\n",
		defined($options{"nointr"}) ? "" : "checked";
	printf "<input type=radio name=nfs_nointr value=1 %s> No</td>\n",
		defined($options{"nointr"}) ? "checked" : "";

	print "<td><b>Allow Access to Local Devices?</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nodevs value=0 %s> Yes\n",
		defined($options{"nodevs"}) ? "" : "checked";
	printf "<input type=radio name=nfs_nodevs value=1 %s> No</td> </tr>\n",
		defined($options{"nodevs"}) ? "checked" : "";
	}
if ($_[0] eq "hfs") {
	print "<tr> <td><b>Read-Only?</b></td>\n";
	printf "<td nowrap><input type=radio name=hfs_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=hfs_ro value=0 %s> No</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>Disallow setuid programs?</b></td>\n";
	printf "<td nowrap><input type=radio name=hfs_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=hfs_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

        print "<tr> <td><b>Enable quotas at boot time?</b></td>\n";
        printf "<td nowrap><input type=radio name=hfs_quota value=1 %s> Yes\n",
		defined($options{"quota"}) ? "checked" : "";
        printf "<input type=radio name=hfs_quota value=0 %s> No</td> </tr>\n",
		defined($options{"quota"}) ? "" : "checked";
	}
if ($_[0] eq "vxfs") {
	print "<tr> <td><b>Read-Only?</b></td>\n";
	printf "<td nowrap><input type=radio name=jfs_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=jfs_ro value=0 %s> No</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>Disallow setuid programs?</b></td>\n";
	printf "<td nowrap><input type=radio name=jfs_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=jfs_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<tr> <td><b>Full integrity for all Metadata?</b></td>\n";
	printf "<td nowrap><input type=radio name=jfs_log value=1 %s> Yes\n",
		defined($options{"log"}) ? "checked" : "";
	printf "<input type=radio name=jfs_log value=0 %s> No</td>\n",
		defined($options{"log"}) ? "" : "checked";

	print "<td><b>Synchronous-write data logging?</b></td>\n";
	printf "<td nowrap><input type=radio name=jfs_syncw value=1 %s> Yes\n",
		!defined($options{"nodatainlog"}) ? "checked" : "";
	printf "<input type=radio name=jfs_syncw value=0 %s> No</td> </tr>\n",
		!defined($options{"nodatainlog"}) ? "" : "checked";

        print "<tr> <td><b>Enable quotas at boot time?</b></td>\n";
        printf "<td nowrap><input type=radio name=jfs_quota value=1 %s> Yes\n",
		defined($options{"quota"}) ? "checked" : "";
        printf "<input type=radio name=jfs_quota value=0 %s> No</td> </tr>\n",
		defined($options{"quota"}) ? "" : "checked";
	}
if ($_[0] eq "cdfs") {
	print "<tr> <td><b>Disallow setuid programs?</b></td>\n";
	printf"<td nowrap><input type=radio name=cdfs_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=cdfs_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "lofs") {
	print "<tr> <td><b>Read-Only?</b></td>\n";
	printf "<td nowrap><input type=radio name=lofs_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=lofs_ro value=0 %s> No</td> </tr>\n",
		defined($options{"ro"}) ? "" : "checked";
	}
if ($_[0] eq "swap") {
	local($i);
	print "<tr> <td><b>Priority</b></td>\n";
	print "<td><select name=swap_pri>\n";
	for ($i = 0; $i < 11; ++$i) {
		printf "<option value=\"%s\" %s>%s</option>\n",
			$i, $options{"pri"} == $i ? "selected" : "", $i;
		}
	print "</select></td> </tr>\n";
	}
if ($_[0] eq "swapfs") {
	# The caching filesystem has lots of options.. cachefs mounts can
	# be of an existing 'manually' mounted back filesystem, or of a
	# back-filesystem that has been automatically mounted by the cache.
	# The user should never see the automatic mountings made by cachefs.
	print "<tr> <td><b>Real filesystem type</b></td>\n";
	print "<td nowrap><select name=cfs_backfstype>\n";
	if (!defined($options{backfstype})) { $options{backfstype} = "nfs"; }
	foreach (&list_fstypes()) {
		if ($_ eq "cachefs") { next; }
		printf "<option value=\"$_\" %s>$_</option>\n",
			$_ eq $options{backfstype} ? "selected" : "";
		}
	print "</select></td>\n";

	print "<td><b>Real mount point</b></td>\n";
	printf"<td nowrap><input type=radio name=cfs_noback value=1 %s> Automatic\n",
		defined($options{"backpath"}) ? "" : "checked";
	printf "<input type=radio name=cfs_noback value=0 %s>\n",
		defined($options{"backpath"}) ? "checked" : "";
	print "<input size=10 name=cfs_backpath value=\"$options{backpath}\"></td> </tr>\n";

	print "<tr> <td><b>Cache directory</b></td>\n";
	printf "<td nowrap><input size=10 name=cfs_cachedir value=\"%s\"></td>\n",
		defined($options{"cachedir"}) ? $options{"cachedir"} : "/cache";

	print "<td><b>Write mode</b></td>\n";
	printf"<td nowrap><input type=radio name=cfs_wmode value=0 %s> Write-around\n",
		defined($options{"non-shared"}) ? "" : "checked";
	printf "<input type=radio name=cfs_wmode value=1 %s> Non-shared\n",
		defined($options{"non-shared"}) ? "checked" : "";
	print "</td> </tr>\n";

	print "<tr> <td><b>Consistency check</b></td>\n";
	print "<td><select name=cfs_con>\n";
	print "<option value=1>Periodically</option>\n";
	printf "<option value=0 %s>Never</option>\n",
		defined($options{"noconst"}) ? "selected" : "";
	printf "<option value=2 %s>On demand</option>\n",
		defined($options{"demandconst"}) ? "selected" : "";
	print "</select></td>\n";

	print "<td><b>Check permissions in cache?</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_local value=1 %s> Yes\n",
		defined($options{"local-access"}) ? "checked" : "";
	printf "<input type=radio name=cfs_local value=0 %s> No</td> </tr>\n",
		defined($options{"local-access"}) ? "" : "checked";

	print "<tr> <td><b>Read-Only?</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=cfs_ro value=0 %s> No</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>Disallow setuid programs?</b></td>\n";
	printf "<td nowrap><input type=radio name=cfs_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=cfs_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";
	}
if ($_[0] eq "autofs") {
	# Autofs has lots of options, depending on the type of file
	# system being automounted.. the fstype options determines this
	local($fstype);
	$fstype = $options{fstype} eq "" ? "nfs" : $options{fstype};
	&generate_options($fstype);
	print "<input type=hidden name=autofs_fstype value=\"$fstype\">\n";
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
elsif ($_[0] eq "hfs") {
	# Get the device name
	if ($in{hfs_dev} == 0) {
		$in{hfs_c} =~ /^[0-9]+$/ ||
			&error("'$in{hfs_c}' is not a valid SCSI controller");
		$in{hfs_t} =~ /^[0-9]+$/ ||
			&error("'$in{hfs_t}' is not a valid SCSI target");
		$in{hfs_d} =~ /^[0-9]+$/ ||
			&error("'$in{hfs_d}' is not a valid SCSI unit");
		$in{hfs_s} =~ /^[0-9]+$/ ||
			&error("'$in{hfs_s}' is not a valid SCSI partition");
		$dv = "/dev/dsk/c$in{hfs_c}t$in{hfs_t}d$in{hfs_d}s$in{hfs_s}";
		}
	elsif ($in{hfs_dev} == 1) {
		$in{hfs_vg} =~ /^[0-9]+$/ ||
			&error("'$in{hfs_vg}' is not a valid Volume Group");
		$in{hfs_lv} =~ /^\S+$/ ||
			&error("'$in{hfs_lv}' is not a valid Logical Volume");
		$dv = "/dev/vg$in{hfs_vg}/$in{hfs_lv}";
		}
	else {
		$in{hfs_path} =~ /^\/\S+$/ ||
			&error("'$in{hfs_path}' is not a valid pathname");
		$dv = $in{hfs_path};
		}

	&fstyp_check($dv, "hfs");
	return $dv;
	}
elsif ($_[0] eq "vxfs") {
	# Get the device name
	if ($in{jfs_dev} == 0) {
		$in{jfs_c} =~ /^[0-9]+$/ ||
			&error("'$in{jfs_c}' is not a valid SCSI controller");
		$in{jfs_t} =~ /^[0-9]+$/ ||
			&error("'$in{jfs_t}' is not a valid SCSI target");
		$in{jfs_d} =~ /^[0-9]+$/ ||
			&error("'$in{jfs_d}' is not a valid SCSI unit");
		$in{jfs_s} =~ /^[0-9]+$/ ||
			&error("'$in{jfs_s}' is not a valid SCSI partition");
		$dv = "/dev/dsk/c$in{jfs_c}t$in{jfs_t}d$in{jfs_d}s$in{jfs_s}";
		}
	elsif ($in{jfs_dev} == 1) {
		$in{jfs_vg} =~ /^[0-9]+$/ ||
			&error("'$in{jfs_vg}' is not a valid Volume Group");
		$in{jfs_lv} =~ /^\S+$/ ||
			&error("'$in{jfs_lv}' is not a valid Logical Volume");
		$dv = "/dev/vg$in{jfs_vg}/$in{jfs_lv}";
		}
	else {
		$in{jfs_path} =~ /^\/\S+$/ ||
			&error("'$in{jfs_path}' is not a valid pathname");
		$dv = $in{jfs_path};
		}

	&fstyp_check($dv, "vxfs");
	return $dv;
	}
elsif ($_[0] eq "lofs") {
	# Get and check the original directory
	$dv = $in{'lofs_src'};
	if (!(-r $dv)) { &error("'$in{lofs_src}' does not exist"); }
	if (!(-d $dv)) { &error("'$in{lofs_src}' is not a directory"); }
	return $dv;
	}
elsif ($_[0] eq "swap") {
	if ($in{swap_dev} == 0) {
		$in{swap_c} =~ /^[0-9]+$/ ||
			&error("'$in{swap_c}' is not a valid SCSI controller");
		$in{swap_t} =~ /^[0-9]+$/ ||
			&error("'$in{swap_t}' is not a valid SCSI target");
		$in{swap_d} =~ /^[0-9]+$/ ||
			&error("'$in{swap_d}' is not a valid SCSI unit");
		$in{swap_s} =~ /^[0-9]+$/ ||
			&error("'$in{swap_s}' is not a valid SCSI partition");
		$dv="/dev/dsk/c$in{swap_c}t$in{swap_t}d$in{swap_d}s$in{swap_s}";
		}
	elsif ($in{swap_dev} == 1) {
		$in{swap_vg} =~ /^[0-9]+$/ ||
			&error("'$in{swap_vg}' is not a valid Volume Group");
		$in{swap_lv} =~ /^\S+$/ ||
			&error("'$in{swap_lv}' is not a valid Logical Volume");
		$dv = "/dev/vg$in{swap_vg}/$in{swap_lv}";
		}
	else {
		$in{swap_path} =~ /^\/\S+$/ ||
			&error("'$in{swap_path}' is not a valid pathname");
		$dv = $in{swap_path};
		}
	&fstyp_check($dv, "swap");
	return $dv;
	}
elsif ($_[0] eq "cdfs") {
	# Get the device name
	if ($in{cdfs_dev} == 0) {
		$in{cdfs_c} =~ /^[0-9]+$/ ||
			&error("'$in{cdfs_c}' is not a valid SCSI controller");
		$in{cdfs_t} =~ /^[0-9]+$/ ||
			&error("'$in{cdfs_t}' is not a valid SCSI target");
		$in{cdfs_d} =~ /^[0-9]+$/ ||
			&error("'$in{cdfs_d}' is not a valid SCSI unit");
		$dv = "/dev/dsk/c$in{cdfs_c}t$in{cdfs_t}d$in{cdfs_d}";
		}
	else {
		$in{cdfs_path} =~ /^\/\S+$/ ||
			&error("'$in{cdfs_path}' is not a valid pathname");
		$dv = $in{cdfs_path};
		}

	&fstyp_check($dv, "cdfs");
	return $dv;
	}
elsif ($_[0] eq "swapfs") {
	# In order to check the location for the caching filesystem, we need
	# to check the back filesystem
	if (!$in{cfs_noback}) {
		# The back filesystem is manually mounted.. hopefully
		local($bidx, @mlist, @binfo);
		$bidx = &get_mounted($in{cfs_backpath}, "*");
		if ($bidx < 0) {
			&error("The back filesystem '$in{cfs_backpath}' is ".
			       "not mounted");
			}
		@mlist = &list_mounted();
		@binfo = @{$mlist[$bidx]};
		if ($binfo[2] ne $in{cfs_backfstype}) {
			&error("The back filesystem is '$binfo[2]', not ".
			       "'$in{cfs_backfstype}'");
			}
		}
	else {
		# Need to automatically mount the back filesystem.. check
		# it for sanity first.
		# But HOW?
		$in{cfs_src} =~ /^\S+$/ ||
			&error("'$in{cfs_src}' is not a valid cache source");
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
			&error("You did not enter an automount map name");
		if ($in{autofs_map} =~ /^\// && !(-r $in{autofs_map})) {
			&error("The map file '$in{autofs_map}' does not exist");
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
}

# fstyp_check(device, type)
# Check if some device exists, and contains a filesystem of the given type,
# using the fstyp command.
sub fstyp_check
{
local($out, $part, $found);

# Check if the device/partition actually exists
if ($_[0] =~ /^\/dev\/dsk\/c(.)t(.)d(.)s(.)$/) {
	# a normal scsi device..
	if (!&open_tempfile(DEV, $_[0], 0, 1)) {
		if ($! =~ /No such file or directory/) {
                	&error("The SCSI target for '$_[0]' does not exist");
			}
		elsif ($! =~ /No such device or address/) {
                	&error("The SCSI target for '$_[0]' does not exist");
			}
		}
	&close_tempfile(DEV);
	}
elsif ($_[0] =~ /^\/dev\/vg([0-9]+)\/(\S+)$/) {
	# Logical Volume device..
	$out = &backquote_command("lvdisplay -v $_[0] 2>&1");
	if ($out =~ /No such file or directory/) {
		&error("The Logical Volume device for '$_[0]' does not exist");
		}
	}
else {
	# Some other device
	if (!&open_tempfile(DEV, $_[0], 0, 1)) {
		if ($! =~ /No such file or directory/) {
			&error("The device file '$_[0]' does not exist");
			}
		elsif ($! =~ /No such device or address/) {
			&error("The device for '$_[0]' does not exist");
			}
		}
	&close_tempfile(DEV);
	}

# Check the filesystem type
if ($_[1] ne "cdfs" && $_[1] ne "swap") {
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
}


# check_options(type)
# Read options for some filesystem from %in, and use them to update the
# %options array. Options handled by the user interface will be set or
# removed, while unknown options will be left untouched.
sub check_options
{
local($k, @rv);
delete($options{"defaults"});

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

	if ($in{hfs_nosuid}) {
		# nosuid
		$options{"nosuid"} = ""; delete($options{"suid"});
		}
	else {
		# suid
		$options{"suid"} = ""; delete($options{"nosuid"});
		}

	delete($options{"soft"}); delete($options{"hard"});
	if ($in{nfs_soft}) { $options{"soft"} = ""; }

	delete($options{"bg"}); delete($options{"fg"});
	if ($in{nfs_bg}) { $options{"bg"} = ""; }

	delete($options{"intr"}); delete($options{"nointr"});
	if ($in{nfs_nointr}) { $options{"nointr"} = ""; }

	delete($options{"devs"}); delete($options{"nodevs"});
	if ($in{nfs_nodevs}) { $options{"nodevs"} = ""; }
	}
elsif ($_[0] eq "hfs") {
	if ($in{hfs_ro}) {
		# read-only
		$options{"ro"} = ""; delete($options{"rw"});
		}
	else {
		# read-write
		$options{"rw"} = ""; delete($options{"ro"});
		}
	if ($in{hfs_nosuid}) {
		# nosuid
		$options{"nosuid"} = ""; delete($options{"suid"});
		}
	else {
		# suid
		$options{"suid"} = ""; delete($options{"nosuid"});
		}
	if ($in{hfs_quota}) {
		# quota
		$options{"quota"} = "";
		}
	else {
		# noquota
		delete($options{"quota"});
		}
	}
elsif ($_[0] eq "vxfs") {
	if ($in{jfs_ro}) {
		# read-only
		$options{"ro"} = ""; delete($options{"rw"});
		}
	else {
		# read-write
		$options{"rw"} = ""; delete($options{"ro"});
		}
	if ($in{jfs_nosuid}) {
		# nosuid
		$options{"nosuid"} = ""; delete($options{"suid"});
		}
	else {
		# suid
		$options{"suid"} = ""; delete($options{"nosuid"});
		}
	if ($in{jfs_log}) {
		# log
		$options{"log"} = ""; delete($options{"delaylog"});
		}
	else {
		# delaylog
		$options{"delaylog"} = ""; delete($options{"log"});
		}
	if ($in{jfs_syncw}) {
		# datainlog
		$options{"datainlog"} = ""; delete($options{"nodatainlog"});
		}
	else {
		# nodatainlog
		$options{"nodatainlog"} = ""; delete($options{"datainlog"});
		}
	if ($in{jfs_quota}) {
		# quota
		$options{"quota"} = "";
		}
	else {
		# noquota
		delete($options{"quota"});
		}
	}
elsif ($_[0] eq "lofs") {
	if ($in{lofs_ro}) {
		# read-only
		$options{"ro"} = "";
		}
	else {
		# read-write
		$options{"defaults"} = "";
		}
	}
elsif ($_[0] eq "swap") {
	$options{"pri"} = $in{swap_pri};
	}
elsif ($_[0] eq "cdfs") {
	# read-only
	$options{"ro"} = "";
	if ($in{cdfs_nosuid}) {
		# nosuid
		$options{"nosuid"} = ""; delete($options{"suid"});
		}
	else {
		# suid
		$options{"suid"} = ""; delete($options{"nosuid"});
		}
	}
elsif ($_[0] eq "tmpfs") {
	# Ram-disk filesystems have only one option
	delete($options{"size"});
	if (!$in{"tmpfs_size_def"}) {
		$options{"size"} = "$in{tmpfs_size}$in{tmpfs_unit}";
		}
	}
elsif ($_[0] eq "swapfs") {
	# The caching filesystem has lots of options
	$options{"backfstype"} = $in{"cfs_backfstype"};

	delete($options{"backpath"});
	if (!$in{"cfs_noback"}) {
		# A back filesystem was given..  (alreadys checked)
		$options{"backpath"} = $in{"cfs_backpath"};
		}

	if ($in{"cfs_cachedir"} !~ /^\/\S+/) {
		&error("'$in{cfs_cachedir}' is not a valid cache directory");
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
	return &check_options($options{"fstype"});
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
local($out, $hostname, $broadcast, @tmp);
$hostname = get_system_hostname();
$out = &backquote_command("netstat -i 2>&1 | grep $hostname", 1);
if ($out =~ /\s+(\S*)\s+(\S*)\s+(.*)/) {
	$broadcast = "$2.255.255.255";
	@tmp = split(/\./,$broadcast);
	$broadcast = "$tmp[0].$tmp[1].$tmp[2].$tmp[3]";
	return $broadcast;
	}
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
