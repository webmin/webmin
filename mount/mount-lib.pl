# mount-lib.pl
# Functions for handling the /etc/[v]fstab file. Some functions are defined in
# here, and some in OS-specific files named <os_type>-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$filesystem_users_file = "$module_config_directory/filesystem-users";
@access_fs = split(/\s+/, $access{'fs'});

# get_mount(directory|'swap', device)
# Returns the index of this mount, or -1 if not known
sub get_mount
{
local(@mlist, $p, $d, $i);
@mlist = &list_mounts();
for($i=0; $i<@mlist; $i++) {
	$p = $mlist[$i];
	if ($_[0] eq "*" && $p->[1] eq $_[1]) {
		# found by match on device
		return $i;
		}
	elsif ($_[1] eq "*" && $p->[0] eq $_[0]) {
		# found by match on directory
		return $i;
		}
	elsif ($p->[0] eq $_[0] && $p->[1] eq $_[1]) {
		# found by match on both
		return $i;
		}
	}
return -1;
}


# get_mounted(directory|'swap', device)
# Returns the index of this current mount, or -1 if not known
sub get_mounted
{
local(@mlist, $p, $d, $i);
@mlist = &list_mounted();
for($i=0; $i<@mlist; $i++) {
	$p = $mlist[$i];
	if ($_[0] eq "*" && $p->[1] eq $_[1]) {
		# found by match on device
		return $i;
		}
	elsif ($_[1] eq "*" && $p->[0] eq $_[0]) {
		# found by match on directory
		return $i;
		}
	elsif ($p->[0] eq $_[0] && $p->[1] eq $_[1]) {
		# found by match on both
		return $i;
		}
	}
return -1;
}


# parse_options(type, options)
# Convert an options string for some filesystem into the associative
# array %options
sub parse_options
{
local($_);
undef(%options);
if ($_[1] ne "-") {
	foreach (split(/,/, $_[1])) {
		if (/^([^=]+)=(.*)$/) { $options{$1} = $2; }
		else { $options{$_} = ""; }
		}
	}
return \%options;
}

# join_options(type, [&hash])
# Returns a string constructed from the %options hash
sub join_options
{
local $h = $_[1] || \%options;
local (@rv, $k);
foreach $k (keys %$h) {
	push(@rv, $h->{$k} eq "" ? $k : $k."=".$h->{$k});
	}
return @rv ? join(",", @rv) : "-";
}

# swap_form(path)
# This function should be called by os-specific code to display a form
# asking for the size of a swap file to create. The form will be submitted
# to a creation program, and then redirected back to the original mount cgi
sub swap_form
{
local ($file) = @_;
&ui_print_header(undef, "Create Swap File", "");
print &ui_form_start("create_swap.cgi");
foreach my $k (keys %in) {
	print &ui_hidden($k, $in{$k});
	}
print &ui_hidden("cswap_file", $file);
print &text('cswap_file', "<tt>$file</tt>"),"<p>\n";
print $text{'cswap_size'},"\n";
print &ui_textbox("cswap_size", undef, 6)," ",
      &ui_select("cswap_units", "m",
		 [ [ "m", "MB" ], [ "g", "GB" ], [ "t", "TB" ] ])."\n";
print &ui_form_end([ [ undef, $text{'create'} ] ]);
&ui_print_footer("", $text{'index_return'});
exit;
}

# nfs_server_chooser_button(input, [form])
sub nfs_server_chooser_button
{
local($form);
$form = @_ > 1 ? $_[1] : 0;
if ($access{'browse'}) {
	return "<input type=button onClick='ifield = document.forms[$form].$_[0]; nfs_server = window.open(\"../$module_name/nfs_server.cgi\", \"nfs_server\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300\"); nfs_server.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
	}
return undef;
}

# nfs_export_chooser_button(serverinput, exportinput, [form])
sub nfs_export_chooser_button
{
local($form);
$form = @_ > 2 ? $_[2] : 0;
if ($access{'browse'}) {
	return "<input type=button onClick='if (document.forms[$form].$_[0].value != \"\") { ifield = document.forms[$form].$_[1]; nfs_export = window.open(\"../$module_name/nfs_export.cgi?server=\"+document.forms[$form].$_[0].value, \"nfs_export\", \"toolbar=no,menubar=no,scrollbars=yes,width=500,height=200\"); nfs_export.ifield = ifield; window.ifield = ifield }' value=\"...\">\n";
	}
return undef;
}

# smb_server_chooser_button(serverinput, [form])
sub smb_server_chooser_button
{
local($form);
$form = @_ > 1 ? $_[1] : 0;
if (&has_command($config{'smbclient_path'}) && $access{'browse'}) {
	return "<input type=button onClick='ifield = document.forms[$form].$_[0]; smb_server = window.open(\"../$module_name/smb_server.cgi\", \"smb_server\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300\"); smb_server.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
	}
return undef;
}

# smb_share_chooser_button(serverinput, shareinput, [form])
sub smb_share_chooser_button
{
local($form);
$form = @_ > 2 ? $_[2] : 0;
if (&has_command($config{'smbclient_path'}) && $access{'browse'}) {
	return "<input type=button onClick='if (document.forms[$form].$_[0].value != \"\") { ifield = document.forms[$form].$_[1]; smb_share = window.open(\"../$module_name/smb_share.cgi?server=\"+document.forms[$form].$_[0].value, \"smb_share\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300\"); smb_share.ifield = ifield; window.ifield = ifield }' value=\"...\">\n";
	}
return undef;
}

# Include the correct OS-specific functions file
if ($gconfig{'os_type'} =~ /^\S+\-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}

# can_edit_fs(dir, device, type, options, [is-new])
# Returns 1 if a filesystem can be edited, 0 otherwise
sub can_edit_fs
{
local $ok = 1;
if (@access_fs) {
	local $d;
	foreach $d (@access_fs) {
		$ok = 0 if (!&is_under_directory($d, $_[0]));
		}
	}
$ok = 0 if (!&can_fstype($_[2]));
if ($access{'user'} && !$_[4]) {
	local $users = &get_filesystem_users();
	$ok = 0 if ($users->{$_[0]} ne $remote_user);
	}
return $ok;
}

# can_fstype(type)
sub can_fstype
{
return 1 if (!$access{'types'});
local @types = split(/\s+/, $access{'types'});
return &indexof($_[0], @types) >= 0;
}

# compile_program(name, default-arch)
# Ensures that some C program is compiled and copied to /etc/webmin . Uses the
# supplied native versions if possible
sub compile_program
{
return if (-r "$module_config_directory/$_[0]" &&
   &execute_command("$module_config_directory/$_[0]", undef, undef, undef, 0, 1) == 0);
local $arch = &backquote_command("uname -m");
$arch =~ s/\r|\n//g;
local $re = $_[1];
if ($re && $arch =~ /^$re$/i && -r "$module_root_directory/$_[0]" &&
    &execute_command("$module_root_directory/$_[0]", undef, undef, undef, 0, 1) == 0) {
	# Compiled program for this architecture already exists and is working,
	# so can just copy
	&execute_command("cp $module_root_directory/$_[0] $module_config_directory/$_[0]");
	}
else {
	# Need to compile
	local ($cc) = (&has_command("gcc") || &has_command("cc") ||
		       &has_command("gcc-4.0") || &has_command("gcc-3.3"));
	$cc || &error($text{'egcc'});
	local $out = &backquote_logged("$cc -o $module_config_directory/$_[0] $module_root_directory/$_[0].c 2>&1");
	if ($?) {
		&error(&text('ecompile', "<pre>$out</pre>"));
		}
	}
&set_ownership_permissions(undef, undef, 0755,"$module_config_directory/$_[0]");
}

# get_filesystem_users()
# Returns a mapping between filesystems and their owners
sub get_filesystem_users
{
local %users;
&read_file($filesystem_users_file, \%users);
return \%users;
}

# save_filesystem_users(&usermap)
# Saves the filesystem owner mapping
sub save_filesystem_users
{
&write_file($filesystem_users_file, $_[0]);
}

# can_delete_directory(mount-point)
# Returns 1 if some directory should be deleted when un-mounting
sub can_delete_directory
{
local @dirs = split(/\s+/, $config{'delete_under'});
return 0 if (!@dirs);
return 0 if ($_[0] eq "swap");
local $d;
foreach $d (@dirs) {
	return 1 if (&is_under_directory($d, $_[0]));
	}
return 0;
}

# delete_unmounted(dir, device)
# If some directory is no longer in the permanent mount list, delete it if it
# is under the list of dirs to auto-delete
sub delete_unmounted
{
if (&can_delete_directory($_[0]) &&
    &get_mount($_[0], $_[1]) < 0) {
	&system_logged("rmdir ".quotemeta($_[0]));
	}
}

# remount_dir(directory, device, type, options)
# Adjusts the options for some mounted filesystem
sub remount_dir
{
if (defined(&os_remount_dir)) {
	return &os_remount_dir(@_);
	}
else {
	local $err = &unmount_dir(@_);
	return $err if ($err);
	return &mount_dir(@_);
	}
}

# filesystem_for_dir(dir)
# Give a directory, returns the details filesystem it is on (dir, device,
# type, options)
sub filesystem_for_dir
{
local @stdir = stat($_[0]);
foreach my $m (&list_mounted()) {
	local @stm = stat($m->[0]);
	if ($stm[0] == $stdir[0]) {
		# Save device number!
		return @$m;
		}
	}
return ( );
}

# local_disk_space([&always-count])
# Returns the total local and free disk space on the system, plus a list of
# per-filesystem total and free
sub local_disk_space
{
my ($always) = @_;
my ($total, $free) = (0, 0);
my @fs;
my @mounted = &mount::list_mounted();
my %donezone;
my %donevzfs;
my %donedevice;
my %donedevno;

# Get list of zone pools
my %zpools = ( 'zones' => 1, 'zroot' => 1 );
if (&has_command("zpool")) {
	my @out = &backquote_command("zpool list -P 2>/dev/null || zpool list -p 2>/dev/null");
	foreach my $l (@out) {
		if (/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
			$zpools{$1} = [ $2 / 1024, $4 / 1024 ];
			}
		}
	}

# Add up all local filesystems
foreach my $m (@mounted) {
	if ($m->[2] =~ /^ext/ ||
	    $m->[2] eq "reiserfs" || $m->[2] eq "ufs" ||
	    $m->[2] eq "zfs" || $m->[2] eq "simfs" || $m->[2] eq "vzfs" ||
	    $m->[2] eq "xfs" || $m->[2] eq "jfs" || $m->[2] eq "btrfs" ||
	    $m->[1] =~ /^\/dev\// ||
	    &indexof($m->[1], @$always) >= 0) {
		my $zp;
		if ($m->[1] =~ /^([^\/]+)(\/(\S+))?/ &&
                    $m->[2] eq "zfs" && $zpools{$1}) {
			# Don't double-count maps from the same zone pool
			next if ($donezone{$1}++);
			$zp = $zpools{$1};
			}
		if ($donedevice{$m->[0]}++ ||
		    $donedevice{$m->[1]}++) {
			# Don't double-count mounts from the same device, or
			# on the same directory.
			next;
			}
		my @st = stat($m->[0]);
		if (@st && $donedevno{$st[0]}++) {
			# Don't double-count same filesystem by device number
			next;
			}
		if ($m->[1] eq "/dev/fuse") {
			# Skip fuse user-space filesystem mounts
			next;
			}
		if ($m->[2] eq "swap") {
			# Skip virtual memory
			next;
			}
		if ($m->[2] eq "squashfs") {
			# Skip /snap mounts
			next;
			}
		if ($m->[1] =~ /^\/dev\/sr/) {
			# Skip CDs
			next;
			}
		# Get the size - for ZFS mounts, this comes from the underlying
		# total pool size and free
		my ($t, $f);
		if ($zp) {
			($t, $f) = @$zp;
			}
		else {
			($t, $f) = &disk_space($m->[2], $m->[0]);
			}
		if (($m->[2] eq "simfs" || $m->[2] eq "vzfs" ||
		     $m->[0] eq "/dev/vzfs" ||
		     $m->[0] eq "/dev/simfs") &&
		    $donevzfs{$t,$f}++) {
			# Don't double-count VPS filesystems
			next;
			}
		$total += $t*1024;
		$free += $f*1024;
		my ($it, $if);
		if (defined(&inode_space)) {
			($it, $if) = &inode_space($m->[2], $m->[0]);
			}
		push(@fs, { 'total' => $t*1024,
			    'free' => $f*1024,
			    'itotal' => $it,
			    'ifree' => $if,
			    'dir' => $m->[0],
			    'device' => $m->[1],
			    'type' => $m->[2] });
		}
	}
return ($total, $free, \@fs);
}

1;

