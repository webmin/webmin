#!/usr/local/bin/perl
# Enable, disable or rescan Btrfs quotas

require './quota-lib.pl';
&ReadParse();
$dir = $in{'dir'};

# Require quota activation access and a valid mounted Btrfs filesystem before
# running any command that can change filesystem quota state.
&can_edit_btrfs_filesys($dir) && $access{'enable'} && !$access{'ro'} ||
	&error($text{'btrfs_eenable'});
defined(&btrfs_quota_status) && &is_btrfs_fs($dir) ||
	&error($text{'btrfs_enotbtrfs'});

# Accept only the three operations implemented by this handler.
$in{'action'} =~ /^(enable|disable|rescan)$/ ||
	&error($text{'btrfs_eaction'});

# Disabling Btrfs quotas removes every qgroup and limit, so require an explicit
# confirmation before performing this destructive operation.
if ($in{'action'} eq "disable" && !$in{'confirm'}) {
	# Mark the filesystem and qgroup terms as literal technical values.
	my $dir_label = &ui_tag("tt", &html_escape($dir));
	my $qgroup_label = &ui_tag("tt", "qgroup");
	chomp($dir_label);
	chomp($qgroup_label);

	# Display the destructive warning inside the confirmation form.
	&ui_print_header(undef, $text{'btrfs_disable'}, "", "btrfs");
	print &ui_confirmation_form(
		"btrfs_action.cgi",
		&text('btrfs_disable_confirm', $dir_label),
		[ [ "dir", $dir ], [ "action", "disable" ] ],
		[ [ "confirm", $text{'btrfs_disable'} ] ],
		&ui_alert_box(&text('btrfs_disable_warning', $qgroup_label), "warn",
			      undef, undef, ""));
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

&error_setup($text{'btrfs_efailed'});
# Enable quotas using the accounting mode selected in the module configuration.
if ($in{'action'} eq "enable") {
	$err = &enable_btrfs_quotas($dir,
		$config{'btrfs_mode'} eq "simple" ? 1 : 0);
	}
# Disable quotas after the confirmation branch above has been completed.
elsif ($in{'action'} eq "disable") {
	$err = &disable_btrfs_quotas($dir);
	}
# The remaining valid action starts a full-accounting quota rescan.
else {
	$err = &rescan_btrfs_quotas($dir, 0);
	}

# Report command failures, record successful changes, and return to the most
# relevant page for the completed action.
&error($err) if ($err);
&webmin_log($in{'action'}, "btrfs", $dir, \%in);
&redirect($in{'action'} eq "rescan" ?
	"list_btrfs.cgi?dir=".&urlize($dir) : "");
