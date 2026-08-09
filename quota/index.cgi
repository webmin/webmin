#!/usr/local/bin/perl
# index.cgi
# Display a list of all local filesystems, and allow editing of quotas
# on those which have quotas turned on. Traditional quota mount options are
# configured in the mount module, while Btrfs quotas are managed here.

require './quota-lib.pl';

# Discover allowed Btrfs mounts independently of the traditional quota tools.
@btrfs = grep { &can_edit_btrfs_filesys($_->[0]) } &list_btrfs_filesystems();
$err = &quotas_init();

# Traditional filesystems are unavailable when quota-tools initialization fails.
@list = $err ? ( ) : &list_filesystems();

# Use focused Btrfs help when it is the only quota model shown on this page.
$help = @btrfs && !@list ? "btrfs" : "intro";
&ui_print_header(undef, $text{'index_title'}, "", $help, 1, 1, 0,
	&help_search_link("quota", "man", "howto"));

# Stop only when neither traditional quota tools nor Btrfs tools can provide a
# usable filesystem list.
if ($err && (!@btrfs || !&has_command("btrfs"))) {
	print "<p><b>$err</b><p>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

if (@list) {
	print &ui_columns_start([
		$text{'index_fs'},
		$text{'index_type'},
		$text{'index_mount'},
		$text{'index_status'},
		$access{'enable'} ? ( $text{'index_action'} ) : (),
		], 100);
	@tds = ( "", "valign=top", "valign=top", "valign=top", "valign=top" );
	foreach $f (@list) {
		$qc = $f->[4];
		$qc = $qc&1 if ($access{'gmode'} == 3);
		$qs = $f->[6];
		next if (!$qc && !$qs);
		next if (!&can_edit_filesys($f->[0]));
		$qn = $f->[5];
		if ($qc == 1) { $msg = $text{'index_quser'}; }
		elsif ($qc == 2) { $msg = $text{'index_qgroup'}; }
		elsif ($qc == 3) { $msg = $text{'index_qboth'}; }
		$canactivate = 1;
		if ($qn >= 4) {
			$chg = $text{'index_mountonly'};
			$qn -= 4;
			$canactivate = 0;
			if ($qn) {
				$msg .= " $text{'index_active'}";
				}
			else {
				$msg .= " $text{'index_inactive'}";
				}
			}
		elsif ($qn) {
			# Currently active
			$msg .= " $text{'index_active'}";
			$chg = $text{'index_disable'};
			}
		elsif ($qc) {
			# Not active, but could be
			$msg .= " $text{'index_inactive'}";
			$chg = $text{'index_enable'};
			}
		else {
			# Not active, and needs setup in /etc/fstab
			$msg = $text{'index_supported'};
			$chg = $text{'index_enable2'};
			}
		if ($qn%2 == 1) { $useractive++; }
		if ($qn > 1) { $groupactive++; }

		local @cols;
		$dir = $f->[0];
		if (!$qn) {
			push(@cols, $dir);
			}
		elsif ($qc == 1) {
			push(@cols, &ui_link("list_users.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir) );
			}
		elsif ($qc == 2) {
			push(@cols, &ui_link("list_groups.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir) );
			}
		elsif ($qc == 3) {
			push(@cols, &ui_link("list_users.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir." (users)").
                    "<br>".
                    &ui_link("list_groups.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir." (groups)") );
			}

		push(@cols, &foreign_call("mount", "fstype_name", $f->[2]));
		push(@cols, &foreign_call("mount", "device_name", $f->[1]));
		push(@cols, $msg);
		if ($access{'enable'}) {
			if ($canactivate) {
				push(@cols, &ui_link("activate.cgi?dir=$dir&active=$qn&mode=$qc", $chg) );
				}
			else {
				push(@cols, $chg);
				}
			}
		print &ui_columns_row(\@cols, \@tds);
		}
	print &ui_columns_end();
	}
# Report no support only when neither traditional nor Btrfs filesystems exist.
elsif (!@btrfs) {
	print "<b>$text{'index_nosupport'}</b><p>\n";
	if (&foreign_available("mount")) {
		print &text('index_mountmod', "../mount/"),"<p>\n";
		}
	}

# Btrfs subvolume quotas use qgroups instead of Unix users and groups, so they
# are shown separately from the traditional quota filesystems above.
if (@btrfs) {
	# Activation controls require both enable permission and write access.
	$btrfs_canactivate = $access{'enable'} && !$access{'ro'};

	# Start a table with an action column only for users who can change state.
	print &ui_columns_start([
		$text{'index_fs'},
		$text{'index_type'},
		$text{'index_mount'},
		$text{'index_status'},
		$btrfs_canactivate ? ( $text{'index_action'} ) : (),
		], 100, 0, undef, &hlink($text{'index_btrfs_title'}, "btrfs"));
	foreach $f (@btrfs) {
		# Query each mount independently so failures remain visible per row.
		undef($action);
		$status = &btrfs_quota_status($f->[0]);

		# The OS library could not identify this path as manageable Btrfs.
		if (!$status) {
			$msg = $text{'index_btrfs_unavailable'};
			}
		# Surface command or parsing errors without offering a state change.
		elsif ($status->{'error'}) {
			$msg = &text('index_btrfs_error',
					&html_escape($status->{'error'}));
			}
		# Disabled filesystems can be enabled using the configured mode.
		elsif (!$status->{'enabled'}) {
			$msg = $text{'index_btrfs_disabled'};
			$action = "enable";
			}
		# Enabled filesystems expose their accounting and consistency state.
		else {
			$mode = $status->{'mode'} eq "squota" ?
				$text{'index_btrfs_simple'} :
				$status->{'mode'} eq "qgroup" ?
				$text{'index_btrfs_full'} :
				$text{'index_btrfs_unknown'};
			$msg = &text('index_btrfs_enabled', $mode);
			$msg .= ", $text{'index_btrfs_inconsistent'}"
				if ($status->{'inconsistent'});
			$action = "disable";
			}

		# Build the common filesystem, type, source and status columns.
		local @cols = (
			&ui_link("list_btrfs.cgi?dir=".&urlize($f->[0]),
				 &html_escape($f->[0])),
			&foreign_call("mount", "fstype_name", $f->[2]),
			&foreign_call("mount", "device_name", $f->[1]),
			$msg,
			);

		# Add the state-changing link only when the ACL allows it.
		if ($btrfs_canactivate) {
			push(@cols, $action ?
				&ui_link("btrfs_action.cgi?dir=".&urlize($f->[0]).
					 "&action=$action",
					 $action eq "enable" ? $text{'index_enable'} :
							       $text{'index_disable'}) : "-");
			}
		print &ui_columns_row(\@cols);
		}

	# Close the separately titled Btrfs filesystem table.
	print &ui_columns_end();
	}

# Buttons to edit and specific user or group
if ($useractive || $groupactive) {
	print &ui_hr();
	print &ui_buttons_start();
	}
if ($useractive) {
	print &ui_buttons_row("user_filesys.cgi", $text{'index_euser'},
			      $text{'index_euserdesc'}, undef,
			      &ui_user_textbox("user"));
	}
if ($groupactive) {
	print &ui_buttons_row("group_filesys.cgi", $text{'index_egroup'},
			      $text{'index_egroupdesc'}, undef,
			      &ui_group_textbox("group"));
	}
if ($useractive || $groupactive) {
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index_return'});

