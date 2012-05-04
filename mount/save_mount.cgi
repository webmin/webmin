#!/usr/local/bin/perl
# save_mount.cgi
# Save or create a mount. When saving an existing mount, at lot of different
# things can happen. 

require './mount-lib.pl';
&error_setup($text{'save_err'});
&ReadParse();
$| = 1;

# Check for redirect to proc module to list processes on the FS
if ($in{'lsof'}) {
	&redirect("../proc/index_search.cgi?mode=3&fs=".&urlize($in{'lsoffs'}));
	return;
	}

# check inputs
if ($in{type} ne "swap") {
	if ($in{directory} !~ /^\//) {
		if (@access_fs && $in{directory}) {
			# Assume relative to allowed dir
			$in{directory} = $access_fs[0]."/".$in{directory};
			}
		else {
			&error(&text('save_edirname', $in{'directory'}));
			}
		}
	if (-r $in{'directory'} && !(-d $in{'directory'})) {
		&error(&text('save_edir', $in{'directory'}));
		}
	# non-existant directories get created later
	}
else {
	# for swap files, set the directory to 'swap'
	$in{directory} = "swap";
	}
&can_edit_fs($in{'directory'}, undef, $in{'type'}, undef, 1) &&
	!$access{'only'} || &error($text{'edit_ecannot'});
$access{'create'} || defined($in{'old'}) || &error($text{'edit_ecannot2'});

# Get user choices
@mmodes = &mount_modes($in{type});
$msave = ($mmodes[0]==0 ? 0 : $in{msave});
$mnow = ($mmodes[1]==0 ? $msave : $in{mmount});

foreach $f (&files_to_lock()) {
	&lock_file($f);
	}
if (defined($in{old})) {
	# Saving an existing mount
	if ($in{temp}) { @mlist = &list_mounted(); }
	else { @mlist = &list_mounts(); }
	@mold = @{$mlist[$in{old}]};

	if (!$mnow && !$in{oldmnow} && !$msave) {
		# Not mounted, so remove from fstab without checking
		$dev = $mold[1];
		}
	else {
		# Changing an existing mount
		$dev = &check_location($in{'type'});
		&parse_options($mold[2], $mold[3]);
		$opts = &check_options($in{'type'}, $dev, $in{'directory'});
		@minfo = ($in{'directory'}, $dev, $in{'type'}, $opts,
			  $mmodes[2] ? $in{'order'} : "-",
			  $in{'msave'}==2||$mmodes[0]==1 ? "yes" : "no");
		}

	# Check for change in device
	if ($mold[1] ne $dev) {
		# Device has changed..check it
		if (!&multiple_mount($minfo[2]) && &get_mounted("*", $dev)>=0) {
			&error(&text('save_ealready', $dev));
			}
		if (!&multiple_mount($minfo[2]) && &get_mount("*", $dev) != -1){
			&error(&text('save_ealready2', $dev));
			}
		$changed = 1;
		}

	# Check for change in directory
	if ($in{type} ne "swap" && $mold[0] ne $in{directory}) {
		# Directory has changed.. check it too
		if (&get_mounted($in{directory}, "*")>=0) {
			&error(&text('save_ealready3', $in{'directory'}));
			}
		if (&get_mount($in{directory}, "*") != -1) {
			&error(&text('save_ealready4', $in{'directory'}));
			}
		$changed = 1;

		if (!(-d $in{directory})) {
			# Create the new directory
			&lock_file($in{directory});
			&make_dir($in{directory}, 0755) ||
				&error(&text('save_emkdir',
					     $in{'directory'}, $!));
			&unlock_file($in{directory});
			$made_dir = 1;
			}
		}

	# Check for change in current mount status
	if ($in{'oldmnow'} && $mmodes[3] == 1) {
		# Mounted, and cannot be unmounted
		}
	elsif ($in{'oldmnow'} && !$mnow) {
		# Just been unmounted..
		if ($error = &unmount_dir($mold[0], $mold[1], $in{'type'},
					  $mold[3], $in{'force'})) {
			if (!$in{'force'} &&
			    $error =~ /busy|Invalid argument/ &&
			    defined(&can_force_unmount_dir) &&
			    &can_force_unmount_dir(@mold)) {
				# Mount is busy.. most likely because it is
				# currently in use. Offer the user a choice to
				# forcibly un-mount
				&ui_print_header(undef, $text{'edit_title'}, "");
				print &text('save_force', "<tt>$mold[0]</tt>"),
				      "<p>\n";
				print "<form action=save_mount.cgi>\n";
				print "<input type=hidden name=force ",
				      "value=1>\n";
				foreach $k (keys %in) {
					print "<input type=hidden name=$k ",
					      "value=\"$in{$k}\">\n";
					}
				print "<center>\n";
				print &ui_submit($text{'save_fapply'}),"\n";
				print "</center>\n";
				print "</form>\n";

				&ui_print_footer("", $text{'index_return'});
				exit;
				}
			else {
				&error(&text('save_eumount', $error));
				}
			}
		@tlog = ( "umount", "dir", $mold[0],
			  { 'dir' => $mold[0], 'dev' => $mold[1],
			    'type' => $mold[2], 'opts' => $mold[3] } );
		}
	elsif ($mnow && !$in{oldmnow}) {
		# Just been mounted..
		if ($error = &mount_dir(@minfo)) {
			&error(&text('save_emount', $error));
			}
		@tlog = ( "mount", "dir", $minfo[0], 
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}
	elsif (!$mnow && !$in{oldmnow}) {
		# Not mounted, and doesn't need to be
		}
	elsif ($mold[0] eq $minfo[0] && $mold[1] eq $minfo[1] &&
	       &diff_opts($mold[3], $minfo[3]) && !$in{'perm_only'} &&
	       defined(&os_remount_dir)) {
		# Only options have changed .. just call remount
		if ($error = &remount_dir(@minfo)) {
			&error(&text('save_eremount', $error));
			}
		@tlog = ( "remount", "dir", $minfo[0], 
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}
	elsif (($mold[0] ne $minfo[0] || $mold[1] ne $minfo[1] ||
	       &diff_opts($mold[3], $minfo[3])) && !$in{'perm_only'}) {
		# Need to unmount/mount to apply new options
		if ($error = &unmount_dir($mold[0], $mold[1], $in{type})) {
			if ($error =~ /busy|Invalid argument/ && $msave) {
				# Mount is busy.. most likely because it is
				# currently in use. Offer the user a choice
				# to update only the fstab file, rather than
				# the real mount
				&ui_print_header(undef, $text{'edit_title'}, "");
				print &text('save_perm', "<tt>$mold[0]</tt>"),
				      "<p>\n";
				print "<form action=save_mount.cgi>\n";
				print "<input type=hidden name=perm_only ",
				      "value=1>\n";
				foreach $k (keys %in) {
					print "<input type=hidden name=$k ",
					      "value=\"$in{$k}\">\n";
					}
				print "<center>\n";
				print &ui_submit($text{'save_apply'}),"\n";
				print "</center>\n";
				print "</form>\n";

				&ui_print_footer("", $text{'index_return'});
				exit;
				}
			else { &error(&text('save_eremount', $error)); }
			}
		if ($error = &mount_dir(@minfo)) {
			&error(&text('save_eremount', $error));
			}
		@tlog = ( "remount", "dir", $minfo[0], 
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}

	# Check for change in permanence
	if ($in{oldmsave} && !$msave) {
		# Delete from mount table
		&delete_mount($in{old});
		@plog = ( "delete", "dir", $in{'directory'},
			  { 'dir' => $mold[0], 'dev' => $mold[1],
			    'type' => $mold[2], 'opts' => $mold[3] } );
		}
	elsif ($msave && !$in{oldmsave}) {
		# Add to mount table
		&create_mount(@minfo);
		@plog = ( "create", "dir", $in{'directory'},
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}
	elsif (!$msave && !$in{oldmsave}) {
		# Not in mount table
		}
	elsif ($mold[0] ne $minfo[0] || $mold[1] ne $minfo[1] ||
	       $mold[4] != $minfo[4] || $mold[5] ne $minfo[5] ||
	       &diff_opts($mold[3], $minfo[3])) {
		# Apply any changes in mount options
		&change_mount($in{old}, @minfo);
		@plog = ( "modify", "dir", $in{'directory'},
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}

	# If no longer mounted, remove the dir 
	if (&get_mounted(@mold) < 0) {
		&delete_unmounted(@mold);
		}
	}
elsif (defined($in{'old'})) {
	# Doing a simple modification to a mount
	if ($in{temp}) {
		@mlist = &list_mounted();
		$mnow = 1;
		}
	else {
		@mlist = &list_mounts();
		$msave = 1;
		$now = 1 if ($in{'oldmnow'});
		}
	@mold = @{$mlist[$in{old}]};

	if ($in{'umount'}) {
		# Just unmount the filesystem
		if ($error = &unmount_dir($mold[0], $mold[1], $in{type})) {
			&error(&text('save_eumount', $error));
			}
		&delete_unmounted(@mold);
		$mnow = 0;
		}
	elsif ($in{'mount'}) {
		# Just mount the filesystem
		if ($error = &mount_dir(@mold)) {
			&error(&text('save_emount', $error));
			}
		$mnow = 1;
		}
	elsif ($in{'perm'}) {
		# Add to permanent mount list
		&create_mount($mold[0], $mold[1], $mold[2], $mold[3],
			      2, "yes");
		$msave = 1;
		}
	elsif ($in{'delete'}) {
		if ($in{'oldmnow'}) {
			# Unmount first
			if ($error = &unmount_dir($mold[0], $mold[1],
						  $in{type})) {
				&error(&text('save_eumount', $error));
				}
			$mnow = 0;
			}
		# Remove from permanent list
		&delete_mount($in{'old'});
		&delete_unmounted(@mold);
		$msave = 0;
		}
	else {
		# Updating the mount in some way ..
		# Check the mount source
		$dev = &check_location($in{'type'});
		&parse_options($mold[2], $mold[3]);
		if (defined($access{'opts'}) &&
		    $access{'opts'} !~ /$in{'type'}/) {
			# Just use existing options
			local @opts;
			foreach $k (keys %options) {
				if ($options{$k} eq '') { push(@opts, $k); }
				else { push(@opts, "$k=$options{$k}"); }
				}
			$opts = @opts ? join(",", @opts) : "-";
			}
		else {
			# Get options from the user
			$opts = &check_options($in{'type'}, $dev,
					       $in{'directory'});
			}
		@minfo = ($in{'directory'}, $dev, $in{'type'}, $opts, 2, 'yes');

		# Check for change in device
		if ($mold[1] ne $dev) {
			# Device has changed..check it
			if (!&multiple_mount($minfo[2]) &&
			    &get_mounted("*", $dev)>=0) {
				&error(&text('save_ealready', $dev));
				}
			if (!&multiple_mount($minfo[2]) &&
			    &get_mount("*", $dev) != -1){
				&error(&text('save_ealready2', $dev));
				}
			$changed = 1;
			}

		# Check for change in directory
		if ($in{type} ne "swap" && $mold[0] ne $in{directory}) {
			# Directory has changed.. check it too
			if (&get_mounted($in{directory}, "*")>=0) {
				&error(&text('save_ealready3',
					     $in{'directory'}));
				}
			if (&get_mount($in{directory}, "*") != -1) {
				&error(&text('save_ealready4',
					     $in{'directory'}));
				}
			$changed = 1;

			if (!(-d $in{directory})) {
				# Create the new directory
				&lock_file($in{directory});
				&make_dir($in{directory}, 0755) ||
					&error(&text('save_emkdir',
						     $in{'directory'}, $!));
				&unlock_file($in{directory});
				$made_dir = 1;
				}
			}

		if ($in{'oldmnow'} && ($mold[0] ne $minfo[0] ||
		    $mold[1] ne $minfo[1] || &diff_opts($mold[3], $minfo[3]))) {
			# Need to unmount/mount to apply new options
			if ($error=&unmount_dir($mold[0], $mold[1], $in{type})){
				&error(&text('save_eremount', $error));
				}
			if ($error = &mount_dir(@minfo)) {
				&error(&text('save_eremount', $error));
				}
			}

		if ($in{'oldmsave'}) {
			# Change entry in fstab
			&change_mount($in{'old'}, @minfo);
			}
		}
	}
else {
	# Creating a new mount, complex interface
	$dev = &check_location($in{type});
	&parse_options($minfo[3]);
	$opts = &check_options($in{type}, $dev, $in{'directory'});
	@minfo = ($in{directory}, $dev, $in{type}, $opts,
		  $mmodes[2] ? $in{order} : "-",
		  $in{msave}==2||$mmodes[0]==1 ? "yes" : "no");

	# Check if anything is being done
	if (!$msave && !$mnow) {
		&error($text{'save_enone'});
		}

	# Check if the device is in use
	if (!&multiple_mount($minfo[2]) && &get_mounted("*", $dev)>=0) {
		&error(&text('save_ealready', $dev));
		}
	if (!&multiple_mount($minfo[2]) && &get_mount("*", $dev) != -1) {
		&error(&text('save_ealready2', $dev));
		}

	# Check if the directory is in use
	if ($in{type} ne "swap") {
		if (&get_mounted($in{directory}, "*")>=0) {
			&error(&text('save_ealready2', $in{'directory'}));
			}
		if (&get_mount($in{directory}, "*") != -1) {
			&error(&text('save_ealready3', $in{'directory'}));
			}
		}

	# Create the directory
	if ($in{type} ne "swap" && !(-d $in{directory})) {
		&lock_file($in{directory});
		&make_dir($in{directory}, 0755) ||
		  &error(&text('save_emkdir', $in{'directory'}, $!));
		&unlock_file($in{directory});
		$made_dir = 1;
		}

	# If mounting now, attempt to do it
	if ($mnow) {
		# If the mount fails, give up totally
		if ($error = &mount_dir($minfo[0], $minfo[1],
					$minfo[2], $minfo[3])) {
			if ($made_dir) { rmdir($in{directory}); }
			&error(&text('save_emount', $error));
			}
		@tlog = ( "mount", "dir", $in{'directory'},
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}

	# If saving, save now
	if ($msave) {
		&create_mount(@minfo);
		@plog = ( "create", "dir", $in{'directory'},
			  { 'dir' => $minfo[0], 'dev' => $minfo[1],
			    'type' => $minfo[2], 'opts' => $minfo[3] } );
		}
	}
foreach $f (&files_to_lock()) {
	&unlock_file($f);
	}
&webmin_log(@plog) if (@plog);
%tpmap = ( 'create', 'mount',  'delete', 'umount',  'modify', 'remount' );
if (@tlog && $tpmap{$plog[0]} ne $tlog[0]) {
	&webmin_log(@tlog);
	}

# Mark this mount and owned by this current user
$users = &get_filesystem_users();
if ($msave || $mnow) {
	$users->{$in{'directory'}} ||= $remote_user;
	}
else {
	delete($users->{$in{'directory'}});
	}
&save_filesystem_users($users);

&redirect($in{'return'});

# undo_changes
# Put back any changes to the fstab file
sub undo_changes
{
if ($in{temp} && $in{mboot}) {
	# a mount was made permanent.. undo by deleting it
	&delete_mount($idx);
	}
elsif (!$in{temp} && !$in{mboot}) {
	# a permanent mount was made temporary.. undo by making it permanent
	&create_mount(@mold);
	}
elsif ($in{mboot}) {
	# some mount options were changed.. undo by changing back
	&change_mount($in{old}, @mold);
	}
if ($made_dir) {
	# A directory for mounting was created.. delete it
	rmdir($in{directory});
	}
}

# diff_opts(string1, string2)
sub diff_opts
{
local $o1 = join(",", sort { $a cmp $b } split(/,/, $_[0]));
local $o2 = join(",", sort { $a cmp $b } split(/,/, $_[1]));
return $o1 ne $o2;
}

