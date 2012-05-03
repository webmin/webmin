# irix-lib.pl
# Filesystem functions for IRIX
# XXX logging and locking?

# Return information about a filesystem, in the form:
#  directory, device, type, options, fsck_order, mount_at_boot
# If a field is unused or ignored, a - appears instead of the value.
# Swap-filesystems (devices or files mounted for VM) have a type of 'swap',
# and 'swap' in the directory field
sub list_mounts
{
local(@rv, @p, $_, $i); $i = 0;
open(FSTAB, $config{'fstab_file'});
while(<FSTAB>) {
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	$rv[$i] = [ $p[1], $p[0], $p[2] ];
	$rv[$i]->[5] = "yes";
	local @o = split(/,/ , $p[3] eq "defaults" ? "" : $p[3]);
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

# List automount points
open(AUTOTAB, $config{'autofs_file'});
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
local($len, @mlist, $fcsk, $dir);
if ($_[2] eq "autofs") {
	# An autofs mount.. add to /etc/auto_master
	$len = grep { $_->[2] eq "autofs" } (&list_mounts());
	&open_tempfile(AUTOTAB, ">> $config{autofs_file}");
	&print_tempfile(AUTOTAB, "$_[0] $_[1]",($_[3] eq "-" ? "" : " -$_[3]"),"\n");
	&close_tempfile(AUTOTAB);
	&system_logged("autofs -r >/dev/null 2>&1 </dev/null");
	}
else {
	# Add to the fstab file
	$len = grep { $_->[2] ne "autofs" } (&list_mounts());
	&open_tempfile(FSTAB, ">> $config{fstab_file}");
	&print_tempfile(FSTAB, "$_[1]  $_[0]  $_[2]");
	local $opts = $_[3] eq "-" ? "" : $_[3];
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
	&close_tempfile(FSTAB);
	}
return $len;
}


# delete_mount(index)
# Delete some mount from the table
sub delete_mount
{
local(@fstab, @autotab, $i, $line, $_);
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

local $found;
open(AUTOTAB, $config{autofs_file});
@autotab = <AUTOTAB>;
close(AUTOTAB);
&open_tempfile(AUTOTAB, "> $config{autofs_file}");
foreach (@autotab) {
	chop; ($line = $_) =~ s/#.*$//g;
	if ($line =~ /\S/ && $line !~ /^[+\-]/ && $i++ == $_[0]) {
		# found line not to include..
		$line =~ /^(\S+)/;
		$found = $1;
		}
	else {
		&print_tempfile(AUTOTAB, $_,"\n");
		}
	}
&close_tempfile(AUTOTAB);
if ($found) {
	&system_logged("autofs -r >/dev/null 2>&1 </dev/null");
	&system_logged("umount $found >/dev/null 2>&1 </dev/null");
	}
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
		&print_tempfile(FSTAB, "$_[2]  $_[1]  $_[3]");
		local $opts = $_[4] eq "-" ? "" : $_[4];
		if ($_[6] eq "no") {
			$opts = join(',' , (split(/,/ , $opts) , "noauto"));
			}
		if ($opts eq "") {
			&print_tempfile(FSTAB, "  defaults");
			}
		else {
			&print_tempfile(FSTAB, "  $opts");
			}
		&print_tempfile(FSTAB, "  0  ");
		&print_tempfile(FSTAB, $_[5] eq "-" ? "0\n" : "$_[5]\n");
		}
	else {
		&print_tempfile(FSTAB, $_,"\n");
		}
	}
&close_tempfile(FSTAB);

local $found;
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
		$found++;
		}
	else {
		&print_tempfile(AUTOTAB, $_,"\n");
		}
	}
&close_tempfile(AUTOTAB);
if ($found) {
	&system_logged("autofs -r >/dev/null 2>&1 </dev/null");
	}
}


# list_mounted()
# Return a list of all the currently mounted filesystems and swap files.
# The list is in the form:
#  directory device type options
# For swap files, the directory will be 'swap'
sub list_mounted
{
local(@rv, @p, $_, $i, $r);
&open_execute_command(SWAP, "swap -l 2>/dev/null", 1, 1);
while(<SWAP>) {
	if (/^\s*\d+\s+(\/\S+)/) {
		push(@rv, [ "swap", $1, "swap", "-" ]);
		}
	}
close(SWAP);
open(MTAB, "/etc/mtab");
while(<MTAB>) {
	s/#.*$//g; if (!/\S/) { next; }
	@p = split(/\s+/, $_);
	push(@rv, [ $p[1], $p[0], $p[2], $p[3] ]);
	}
close(MTAB);
return @rv;
}


# mount_dir(directory, device, type, options)
# Mount a new directory from some device, with some options. Returns 0 if ok,
# or an error string if failed. If the directory is 'swap', then mount as
# virtual memory.
sub mount_dir
{
local($out, $opts);
if ($_[2] eq "swap") {
	# Adding a swap device
	$out = &backquote_logged("swap -a $_[1] 2>&1");
	if ($?) { return $out; }
	}
elsif ($_[2] eq "autofs") {
	# Do nothing, because autofs -r will be run after the auto_master file
	# is updated.
	}
else {
	# Mounting a directory
	$opts = $_[3] eq "-" ? "" : "-o \"$_[3]\"";
	$out = &backquote_logged("mount -t $_[2] $opts $_[1] $_[0] 2>&1");
	if ($?) { return $out; }
	}
return 0;
}


# unmount_dir(directory, device, type)
# Unmount a directory (or swap device) that is currently mounted. Returns 0 if
# ok, or an error string if failed
sub unmount_dir
{
if ($_[2] eq "swap") {
	$out = &backquote_logged("swap -d $_[1] 2>&1");
	}
elsif ($_[2] eq "autofs") {
	# Do nothing - see the comment in mount_dir
	return 0;
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
    /Mounted on\n\S+\s+\S+\s+(\S+)\s+\S+\s+(\S+)/) {
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
return ("xfs","efs","nfs","iso9660","dos","autofs","swap");
}


# fstype_name(type)
# Given a short filesystem type, return a human-readable name for it
sub fstype_name
{
local(%fsmap);
%fsmap = ("xfs","SGI Filesystem",
	  "nfs","Network Filesystem",
	  "cachefs","Caching Filesystem",
	  "iso9660","ISO9660 CD-ROM",
	  "dos","MS-DOS Filesystem",
	  "efs","Old SGI Filesystem",
	  "fd","File Descriptor Filesystem",
	  "hfs","Macintosh Filesystem",
	  "kfs","AppleShare Filesystem",
	  "proc","Process Image Filesystem",
	  "hwgfs","Hardware Configuration Filesystem",
	  "autofs","Automounter Filesystem",
	  "nfs3","NIS Maps Filesystem",
	  "swap","Virtual Memory");
return $config{long_fstypes} && $fsmap{$_[0]} ? $fsmap{$_[0]} : uc($_[0]);
}


# mount_modes(type, dir, device)
# Given a filesystem type, returns 5 numbers that determine how the file
# system can be mounted, and whether it can be fsck'd
sub mount_modes
{
if ($_[0] eq "swap") {
	return $_[2] eq "/dev/swap" ? (1, 0, 0, 0, 1) : (1, 1, 0, 0);
	}
elsif ($_[0] eq "fd" || $_[0] eq "proc" || $_[0] eq "hwgfs" ||
       $_[0] eq "nfs3") {
	return (1, 0, 0, 1);
	}
elsif ($_[0] eq "xfs" || $_[0] eq "efs" || $_[0] eq "cachefs") {
	return (2, 1, 1, 0);
	}
elsif ($_[0] eq "autofs") {
	return (1, 0, 0, 0);
	}
else {
	return (2, 1, 0, 0);
	}
}

# multiple_mount(type)
# Returns 1 if filesystems of this type can be mounted multiple times, 0 if not
sub multiple_mount
{
return ($_[0] eq "nfs" || $_[0] eq "kfs" || $_[0] eq "cachefs");
}


# generate_location(type, location)
# Output HTML for editing the mount location of some filesystem.
sub generate_location
{
if ($_[0] eq "nfs") {
	# NFS mount from some host and directory
	local ($nfshost, $nfspath) = $_[1] =~ /^([^:]+):(.*)/ ? ( $1, $2 ) : ();
	print "<tr> <td><b>$text{'irix_nhost'}</b></td>\n";
	print "<td><input name=nfs_host size=20 value=\"$nfshost\">\n";
	print &nfs_server_chooser_button("nfs_host");
	print "</td>\n";
	print "<td><b>$text{'irix_ndir'}</b></td>\n";
	print "<td><input name=nfs_dir size=20 value=\"$nfspath\">\n";
	print &nfs_export_chooser_button("nfs_host", "nfs_dir");
	print "</td> </tr>\n";
	}
elsif ($_[0] eq "autofs") {
	# Selecting an automounter map
	print "<tr> <td valign=top><b>$text{'irix_auto'}</b></td>\n";
	print "<td colspan=3>\n";
	printf "<input type=radio name=auto_mode value=0 %s> %s<br>\n",
		$_[1] eq "-hosts" ? "checked" : "", $text{'irix_autohosts'};
	printf "<input type=radio name=auto_mode value=1 %s> %s\n",
		$_[1] eq "-hosts" ? "" : "checked", $text{'irix_automap'};
	printf "<input name=auto_map size=30 value='%s'><br>\n",
		$_[1] eq "-hosts" ? "" : $_[1];
	}
elsif ($_[0] eq "iso9660") {
	# Selecting an entire SCSI disk
	print "<tr> <td valign=top><b>$text{'irix_cd'}</b></td>\n";
	print "<td colspan=3>\n";
	local ($mode, $ctrlr, $drive, $other);
	if ($_[1] =~ /^\/dev\/rdsk\/dks(\d+)d(\d+)vol$/) {
		$mode = 0;
		$ctrlr = $1;
		$drive = $2;
		}
	elsif ($_[1]) {
		$mode = 1;
		$other = $_[1];
		}
	printf "<input type=radio name=irix_mode value=0 %s>\n",
		$mode == 0 ? "checked" : "";
	print &text('irix_mode0cd',
		    "<input name=irix_ctrlr size=2 value='$ctrlr'>",
		    "<input name=irix_drive size=2 value='$drive'>"),"<br>\n";
	printf "<input type=radio name=irix_mode value=1 %s> %s\n",
		$mode == 1 ? "checked" : "", $text{'irix_mode1'};
	printf "<input name=irix_other size=30 value='%s'><br>\n",
		$mode == 1 ? $other : "";
	print "</td> </tr>\n";

	}
else {
	# Mounting some local disk (or file)
	print "<tr> <td valign=top><b>$text{'irix_part'}</b></td>\n";
	print "<td colspan=3>\n";
	local ($mode, $ctrlr, $drive, $part, $other);
	if ($_[1] =~ /^\/dev\/dsk\/dks(\d+)d(\d+)s(\d+)$/) {
		$mode = 0;
		$ctrlr = $1;
		$drive = $2;
		$part = $3;
		}
	elsif ($_[1]) {
		$mode = 1;
		$other = $_[1];
		}
	printf "<input type=radio name=irix_mode value=0 %s>\n",
		$mode == 0 ? "checked" : "";
	local ($sel, $currctrlr, $currdrive);
	open(VTOC, "prtvtoc -a |");
	while(<VTOC>) {
		if (/^\/dev\/rdsk\/dks(\d+)d(\d+)vh/) {
			$currctrlr = $1;
			$currdrive = $2;
			}
		elsif (/^\/dev/) {
			undef($currctrlr);
			}
		elsif (/^\s*(\d+)\s+(\d+)\s+(\d+)/ && defined($currctrlr)) {
			$sel .= sprintf "<option value=%s %s>%s\n",
				"/dev/dsk/dks${currctrlr}d${currdrive}s$1",
				$currctrlr == $ctrlr && $currdrive == $drive &&
				$1 == $part ? "selected" : "",
				&text('irix_mode0', $currctrlr,$currdrive,"$1");
			}
		}
	close(VTOC);
	if ($sel) {
		print "<select name=irix_sel>\n";
		print $sel;
		print "</select>\n";
		}
	else {
		print &text('irix_mode0',
			    "<input name=irix_ctrlr size=2 value='$ctrlr'>",
			    "<input name=irix_drive size=2 value='$drive'>",
			    "<input name=irix_part size=2 value='$part'>"),"\n";
		}
	print "<br>\n";
	printf "<input type=radio name=irix_mode value=1 %s> %s\n",
		$mode == 1 ? "checked" : "", $text{'irix_mode1'};
	printf "<input name=irix_other size=30 value='%s'><br>\n",
		$mode == 1 ? $other : "";
	print "</td> </tr>\n";
	}
}


# generate_options(type, newmount)
# Output HTML for editing mount options for a partilcar filesystem 
# under this OS
sub generate_options
{
if ($_[0] ne "swap") {
	# All filesystem types have these options
	print "<tr> <td><b>$text{'irix_ro'}</b></td>\n";
	printf "<td nowrap><input type=radio name=irix_ro value=1 %s> Yes\n",
		defined($options{"ro"}) ? "checked" : "";
	printf "<input type=radio name=irix_ro value=0 %s> No</td>\n",
		defined($options{"ro"}) ? "" : "checked";

	print "<td><b>$text{'irix_nosuid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=irix_nosuid value=1 %s> Yes\n",
		defined($options{"nosuid"}) ? "checked" : "";
	printf "<input type=radio name=irix_nosuid value=0 %s> No</td> </tr>\n",
		defined($options{"nosuid"}) ? "" : "checked";

	print "<tr> <td><b>$text{'irix_grpid'}</b></td>\n";
	printf "<td nowrap><input type=radio name=irix_grpid value=0 %s> Yes\n",
		defined($options{"grpid"}) ? "" : "checked";
	printf "<input type=radio name=irix_grpid value=1 %s> No</td>\n",
		defined($options{"grpid"}) ? "checked" : "";

	print "<td><b>$text{'irix_nodev'}</b></td>\n";
	printf "<td nowrap><input type=radio name=irix_nodev value=1 %s> Yes\n",
		defined($options{"nodev"}) ? "checked" : "";
	printf "<input type=radio name=irix_nodev value=0 %s> No</td> </tr>\n",
		defined($options{"nodev"}) ? "" : "checked";
	}
else {
	# No options available for swap
	print "<tr> <td><i>$text{'irix_noopts'}</i></td> </tr>\n";
	}

if ($_[0] eq "nfs") {
	# Irix NFS
	print "<tr> <td><b>$text{'irix_bg'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_bg value=1 %s> Yes\n",
		defined($options{"bg"}) ? "checked" : "";
	printf "<input type=radio name=nfs_bg value=0 %s> No</td>\n",
		defined($options{"bg"}) ? "" : "checked";

	print "<td><b>$text{'irix_soft'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_soft value=1 %s> Yes\n",
		defined($options{"soft"}) ? "checked" : "";
	printf "<input type=radio name=nfs_soft value=0 %s> No</td> </tr>\n",
		defined($options{"soft"}) ? "" : "checked";

	print "<tr> <td><b>$text{'irix_nointr'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_nointr value=0 %s> Yes\n",
		defined($options{"nointr"}) ? "" : "checked";
	printf "<input type=radio name=nfs_nointr value=1 %s> No</td>\n",
		defined($options{"nointr"}) ? "checked" : "";

	print "<td><b>$text{'irix_version'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_vers_def value=1 %s> %s\n",
		defined($options{"vers"}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=nfs_vers_def value=0 %s>\n",
		defined($options{"vers"}) ? "checked" : "";
	print "<input size=2 name=nfs_vers value='$options{vers}'></td></tr>\n";

	print "<tr> <td><b>$text{'irix_proto'}</b></td>\n";
	print "<td nowrap><select name=proto>\n";
	printf "<option value=\"\" %s> Default\n",
		defined($options{"proto"}) ? "" : "selected";
	printf "<option value=tcp %s> TCP\n",
		$options{"proto"} eq "tcp" ? "selected" : "";
	printf "<option value=udp %s> UDP\n",
		$options{"proto"} eq "udp" ? "selected" : "";
	print "</select></td>\n";

	print "<td><b>$text{'irix_port'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_port_def value=1 %s> %s\n",
		defined($options{"port"}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=nfs_port_def value=0 %s>\n",
		defined($options{"port"}) ? "checked" : "";
	print "<input size=5 name=nfs_port value='$options{port}'></td></tr>\n";

	print "<tr> <td><b>$text{'irix_timeo'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_timeo_def value=1 %s> %s\n",
		defined($options{"timeo"}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=nfs_timeo_def value=0 %s>\n",
		defined($options{"timeo"}) ? "checked" : "";
	printf "<input size=5 name=nfs_timeo value='$options{timeo}'></td>\n";

	print "<td><b>$text{'irix_retrans'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_retrans_def value=1 %s> %s\n",
		defined($options{"retrans"}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=nfs_retrans_def value=0 %s>\n",
		defined($options{"retrans"}) ? "checked" : "";
	print "<input size=5 name=nfs_retrans value='$options{retrans}'></td> </tr>\n";

	print "</tr>\n";

	print "<tr> <td><b>$text{'irix_quota'}</b></td>\n";
	printf "<td nowrap><input type=radio name=nfs_quota value=1 %s> %s\n",
		defined($options{"quota"}) ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=nfs_quota value=0 %s> %s</td>\n",
		defined($options{"quota"}) ? "" : "checked", $text{'no'};

	print "</tr>\n";
	}
elsif ($_[0] eq "xfs") {
	# Irix XFS options
	print "<tr> <td><b>$text{'irix_noatime'}</b></td>\n";
	printf "<td nowrap><input type=radio name=xfs_noatime value=0 %s> %s\n",
		defined($options{"noatime"}) ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=xfs_noatime value=1 %s> %s</td>\n",
		defined($options{"noatime"}) ? "checked" : "", $text{'no'};

	print "<td><b>$text{'irix_wsync'}</b></td>\n";
	printf "<td nowrap><input type=radio name=xfs_wsync value=1 %s> %s\n",
		defined($options{"wsync"}) ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=xfs_wsync value=0 %s> %s</td> </tr>\n",
		defined($options{"wsync"}) ? "" : "checked", $text{'no'};

	local $qm = defined($options{"qnoenforce"}) ? 2 :
		    defined($options{"quota"}) ? 1 : 0;
	print "<tr> <td><b>$text{'irix_quota'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=xfs_quota value=1 %s> %s\n",
		$qm == 1 ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=xfs_quota value=2 %s> %s\n",
		$qm == 2 ? "checked" : "", $text{'irix_quotano'};
	printf "<input type=radio name=xfs_quota value=0 %s> %s</td> </tr>\n",
		$qm == 0 ? "checked" : "", $text{'no'};
	}
elsif ($_[0] eq "efs") {
	# Irix EFS (old filesystem) options
	print "<tr> <td><b>$text{'irix_quota'}</b></td>\n";
	printf "<td nowrap><input type=radio name=efs_quota value=1 %s> %s\n",
		defined($options{"quota"}) ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=efs_quota value=0 %s> %s</td>\n",
		defined($options{"quota"}) ? "" : "checked", $text{'no'};

	print "<td><b>$text{'irix_nofsck'}</b></td>\n";
	printf "<td nowrap><input type=radio name=efs_nofsck value=0 %s> %s\n",
		defined($options{"nofsck"}) ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=efs_nofsck value=1 %s> %s</td> </tr>\n",
		defined($options{"nofsck"}) ? "checked" : "", $text{'no'};
	}
elsif ($_[0] eq "dos") {
	# There are no additional dos vfat options
	}
elsif ($_[0] eq "iso9660") {
	# Irix CD-ROM filesystem options
	print "<tr> <td><b>$text{'irix_setx'}</b></td>\n";
	printf "<td nowrap><input type=radio name=iso_setx value=1 %s> %s\n",
		defined($options{"setx"}) ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=iso_setx value=0 %s> %s</td>\n",
		defined($options{"setx"}) ? "" : "checked", $text{'no'};

	local $rock = !defined($options{"norrip"}) &&
		      !defined($options{"noext"});
	print "<td><b>$text{'irix_rock'}</b></td>\n";
	printf "<td nowrap><input type=radio name=iso_rock value=1 %s> %s\n",
		$rock ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=iso_rock value=0 %s> %s</td> </tr>\n",
		$rock ? "" : "checked", $text{'no'};
	}
elsif ($_[0] eq "autofs") {
	# Irix automounter options
	}
}

# check_location(type)
# Parse and check inputs from %in, calling &error() if something is wrong.
# Returns the location string for storing in the fstab file
sub check_location
{
if ($_[0] eq "nfs") {
	# Use ping and showmount to see if the host exists and is up
	local $out = &backquote_command("ping -c 1 '$in{nfs_host}' 2>&1");
	if ($out =~ /unknown host/i) {
		&error(&text('irix_ehost', $in{'nfs_host'}));
		}
	elsif ($out =~ /100\% packet loss/) {
		&error(&text('irix_eloss', $in{'nfs_host'}));
		}
	$out = &backquote_command("showmount -e '$in{nfs_host}' 2>&1");
	if ($out =~ /port mapper failure/i) {
		&error(&text('irix_eshowmount', $in{'nfs_host'}));
		}
	elsif ($?) {
		&error(&text('irix_emountlist', "<pre>$out</pre>"));
		}

	# Validate directory name
	foreach (split(/\n/, $out)) {
		if (/^(\/\S+)/) { $dirlist .= "$1\n"; }
		}
	if ($in{'nfs_dir'} !~ /^\/\S+$/) {
		&error(&text('irix_edirlist', $in{'nfs_dir'}, $in{'nfs_host'},
					      "<pre>$dirlist</pre>"));
		}

	# Try a test mount to see if filesystem is available
	local $temp = &transname();
	&make_dir($temp, 0755);
	local $mout;
	&execute_command("mount $in{'nfs_host'}:$in{'nfs_dir'} $temp 2>&1",
			 undef, \$mout, \$mout);
	if ($mout =~ /No such file or directory/i) {
		&error(&text('irix_enotexist', $in{'nfs_dir'}, $in{'nfs_host'},
			     "<pre>$dirlist</pre>"));
		}
	elsif ($mout =~ /Permission denied/i) {
		&error(&text('irix_epermission', $in{'nfs_dir'},
			     $in{'nfs_host'}));
		}
	elsif ($?) {
		&error(&text('irix_enfserr', $mout));
		}
	# It worked! unmount
	&execute_command("umount $temp");
	&unlink_file($temp);
	return "$in{nfs_host}:$in{nfs_dir}";
	}
elsif ($_[0] eq "autofs") {
	# Check automounter map
	if ($in{'auto_mode'} == 0) {
		return "-hosts";
		}
	else {
		$in{'auto_map'} =~ /^\S+$/ || &error($text{'irix_eautomap2'});
		$in{'auto_map'} =~ /^\// && !-r $in{'auto_map'} &&
			&error(&text('irix_eautomap', $in{'auto_map'}));
		return $in{'auto_map'};
		}
	}
else {
	# Get the device name
	local $dv;
	if ($in{'irix_mode'} == 0 && defined($in{'irix_sel'})) {
		$dv = $in{'irix_sel'};
		}
	elsif ($in{'irix_mode'} == 0) {
		$in{'irix_ctrlr'} =~ /^\d+$/ ||
			&error(&text('irix_ectrlr', $in{'irix_ctrlr'}));
		$in{'irix_drive'} =~ /^\d+$/ ||
			&error(&text('irix_edrive', $in{'irix_drive'}));
		if ($_[0] eq "iso9660") {
			$dv = "/dev/rdsk/dks$in{'irix_ctrlr'}d$in{'irix_drive'}vol";
			}
		else {
			$in{'irix_part'} =~ /^\d+$/ ||
				&error(&text('irix_epart', $in{'irix_part'}));
			$dv = "/dev/dsk/dks$in{'irix_ctrlr'}d$in{'irix_drive'}s$in{'irix_part'}";
			}
		}
	else {
		$dv = $in{'irix_other'};
		}

	# Check the filesystem type
	if ($_[0] eq "xfs" || $_[0] eq "efs") {
		local $out = &backquote_command("fstyp '$dv' 2>&1");
		$out =~ s/[^A-Za-z0-9]//g;
		if ($?) {
			&error(&text('irix_efstyp2', $dv, $out));
			}
		elsif ($out ne $_[0]) {
			&error(&text('irix_efstyp', $dv, $out, $_[0]));
			}
		}

	# Check if the file exists
	if (!-r $dv) {
		if ($_[0] eq "swap") {
			if ($dv =~ /^\/dev/) {
				&error(&text('solaris_eswapfile', $dv));
				}
			else {
				&swap_form($dv);
				}
			}
		else {
			&error(&text('irix_edevice', $dv));
			}
		}
	return $dv;
	}
}


# check_options(type)
# Read options for some filesystem from %in, and use them to update the
# %options array. Options handled by the user interface will be set or
# removed, while unknown options will be left untouched.
sub check_options
{
local($k, @rv);

# Parse options common to all Irix filesystems
if ($_[0] ne "swap") {
	if ($in{'irix_ro'}) {
		# Read-only
		$options{"ro"} = "";
		delete($options{"rw"});
		}
	else {
		# Read-write
		$options{"rw"} = "";
		delete($options{"ro"});
		}

	delete($options{"nosuid"}); delete($options{"suid"});
	if ($in{'irix_nosuid'}) { $options{"nosuid"} = ""; }

	delete($options{"grpid"});
	if ($in{'irix_grpid'}) { $options{"grpid"} = ""; }

	delete($options{"nodev"}); delete($options{"dev"});
	if ($in{'irix_nodev'}) { $options{"nodev"} = ""; }
	}

if ($_[0] eq "nfs") {
	# Parse Irix NFS options
	delete($options{"bg"}); delete($options{"fg"});
	if ($in{nfs_bg}) { $options{"bg"} = ""; }

	delete($options{"soft"}); delete($options{"hard"});
	if ($in{nfs_soft}) { $options{"soft"} = ""; }

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

	delete($options{"retrans"});
	if (!$in{nfs_retrans_def}) { $options{"retrans"} = $in{nfs_retrans};}

	delete($options{"quota"});
	if ($in{'nfs_quota'}) { $options{"quota"} = ""; }
	}
elsif ($_[0] eq "xfs") {
	# Parse Irix XFS options
	delete($options{"noatime"});
	if ($in{'xfs_noatime'}) { $options{"noatime"} = ""; }

	delete($options{"wsync"});
	if ($in{'xfs_wsync'}) { $options{"wsync"} = ""; }

	delete($options{"quota"}); delete($options{"qnoenforce"});
	if ($in{'xfs_quota'} == 2) { $options{"qnoenforce"} = ""; }
	elsif ($in{'xfs_quota'} == 1) { $options{"quota"} = ""; }
	}
elsif ($_[0] eq "iso9660") {
	# Parse Irix ISO9660 options
	delete($options{"setx"});
	if ($in{'iso_setx'}) { $options{"setx"} = ""; }

	delete($options{"norrip"}); delete($options{"rrip"});
	delete($options{"noext"});
	if (!$in{'iso_rock'}) { $options{"noext"} = ""; }
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
$out = &backquote_command("showmount -e ".quotemeta($_[0]), 1);
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
return $_[0] eq "/dev/root" ? $text{'irix_devroot'} :
       $_[0] eq "/dev/swap" ? $text{'irix_devswap'} :
       $_[0] eq "-hosts" ? $text{'irix_autohosts'} :
       $_[0] =~ /^\/dev\/r?dsk\/dks(\d+)d(\d+)s(\d+)$/ ?
	&text('irix_mode0', "$1", "$2", "$3") :
       $_[0] =~ /^\/dev\/r?dsk\/dks(\d+)d(\d+)vol$/ ?
	&text('irix_mode0cd', "$1", "$2", "$3") :
	$_[0];
}

sub files_to_lock
{
return ( $config{'fstab_file'} );
}

1;
