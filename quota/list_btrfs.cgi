#!/usr/local/bin/perl
# Display Btrfs quota status and subvolume qgroups

require './quota-lib.pl';
&ReadParse();
$dir = $in{'dir'};

# Restrict the page to allowed paths on mounted Btrfs filesystems.
&can_edit_btrfs_filesys($dir) || &error($text{'btrfs_eallow'});
defined(&btrfs_quota_status) && &is_btrfs_fs($dir) ||
	&error($text{'btrfs_enotbtrfs'});
&error_setup($text{'btrfs_efailed'});

# Read quota status before building the status and qgroup tables.
$status = &btrfs_quota_status($dir);
$status || &error($text{'btrfs_enotbtrfs'});
&error($status->{'error'}) if ($status->{'error'});

&ui_print_header(undef, $text{'btrfs_title'}, "", "btrfs");

# Map the command's accounting mode to a user-facing label.
$mode = $status->{'mode'} eq "squota" ? $text{'btrfs_simple'} :
	$status->{'mode'} eq "qgroup" ? $text{'btrfs_full'} :
	$text{'btrfs_unknown'};

# Display the current enablement, accounting mode and consistency state.
print &ui_table_start(&text('btrfs_status_header', &html_escape($dir)),
			      "width=100%", 2);
print &ui_table_row($text{'btrfs_status'},
	$status->{'enabled'} ? $text{'btrfs_enabled'} : $text{'btrfs_disabled'});
print &ui_table_row($text{'btrfs_mode'}, $mode) if ($status->{'enabled'});
# Show consistency only when btrfs-progs or the kernel reports it.
if (defined($status->{'inconsistent'})) {
	print &ui_table_row($text{'btrfs_consistency'},
		$status->{'inconsistent'} ? $text{'btrfs_inconsistent'} :
					    $text{'btrfs_consistent'});
	}
print &ui_table_end();

# A disabled filesystem has no qgroups to list or edit.
if (!$status->{'enabled'}) {
	&ui_print_footer("", $text{'btrfs_return'});
	exit;
	}

# Load all qgroups and start the usage and limit table.
$qgroups = &list_btrfs_qgroups($dir, 0, \$listerr);
&error($listerr) if (!$qgroups);
print &ui_columns_start([
	$text{'btrfs_qgroup'},
	$text{'btrfs_path'},
	$text{'btrfs_referenced'},
	$text{'btrfs_exclusive'},
	$text{'btrfs_max_referenced'},
	$text{'btrfs_max_exclusive'},
	], 100, 0, undef, $text{'btrfs_qgroups'});
foreach $q (@$qgroups) {
	# Read-only users and the filesystem-wide top-level qgroup get no edit
	# link. Limiting 0/5 can block Webmin from changing the limit back.
	$qid = &ui_tag("tt", &html_escape($q->{'id'}));
	chomp($qid);
	if (!$access{'ro'} && $q->{'id'} ne "0/5") {
		$qid = &ui_link("edit_btrfs.cgi?dir=".&urlize($dir).
				"&qgroup=".&urlize($q->{'id'}), $qid);
		}

	# Display usage and use the standard unlimited label for missing limits.
	print &ui_columns_row([
		$qid,
		$q->{'path'} ne "" ? &html_escape($q->{'path'}) : "-",
		&nice_size($q->{'referenced'}),
		&nice_size($q->{'exclusive'}),
		defined($q->{'max_referenced'}) ?
			&nice_size($q->{'max_referenced'}) : $text{'quota_unlimited'},
		defined($q->{'max_exclusive'}) ?
			&nice_size($q->{'max_exclusive'}) : $text{'quota_unlimited'},
		]);
	}
print &ui_columns_end();

# Full accounting supports rescanning; simple accounting deliberately hides it.
if (!$access{'ro'} && $access{'enable'} && $status->{'mode'} ne "squota") {
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("btrfs_action.cgi", $text{'btrfs_rescan'},
		$text{'btrfs_rescan_desc'},
		[ [ "dir", $dir ], [ "action", "rescan" ] ]);
	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'btrfs_return'});
