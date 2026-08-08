#!/usr/local/bin/perl
# Edit the limits for a Btrfs qgroup

require './quota-lib.pl';
&ReadParse();
$dir = $in{'dir'};

# Limit editing requires write access to an allowed mounted Btrfs filesystem
# and a syntactically valid qgroup ID.
$access{'ro'} && &error($text{'btrfs_eedit'});
&can_edit_btrfs_filesys($dir) || &error($text{'btrfs_eallow'});
defined(&btrfs_quota_status) && &is_btrfs_fs($dir) ||
	&error($text{'btrfs_enotbtrfs'});
&valid_btrfs_qgroup_id($in{'qgroup'}) || &error($text{'btrfs_eqgroup'});
$in{'qgroup'} eq "0/5" && &error($text{'btrfs_etoplevel'});

# Load the current qgroups and ensure the requested ID still exists.
$qgroups = &list_btrfs_qgroups($dir, 0, \$listerr);
&error($listerr) if (!$qgroups);
($qgroup) = grep { $_->{'id'} eq $in{'qgroup'} } @$qgroups;
$qgroup || &error($text{'btrfs_eqgroup'});

# Start a form bound to the selected filesystem and qgroup.
&ui_print_header(undef, $text{'btrfs_edit_title'}, "", "btrfs");
print "<p>$text{'btrfs_edit_info'}</p>\n";
print &ui_form_start("save_btrfs.cgi", "post");
print &ui_hidden("dir", $dir);
print &ui_hidden("qgroup", $qgroup->{'id'});
print &ui_table_start(&text('btrfs_edit_header',
	&html_escape($qgroup->{'id'}), &html_escape($dir)), "width=100%", 2);

# Show the current path and accounted usage as read-only values.
print &ui_table_row($text{'btrfs_path'},
	$qgroup->{'path'} ne "" ? &html_escape($qgroup->{'path'}) : "-");
print &ui_table_row($text{'btrfs_referenced'},
	&nice_size($qgroup->{'referenced'}));
print &ui_table_row($text{'btrfs_exclusive'},
	&nice_size($qgroup->{'exclusive'}));
print &ui_table_hr();

# Allow referenced and exclusive limits to be changed independently.
print &ui_table_row($text{'btrfs_max_referenced'},
	&quota_input("max_referenced",
		defined($qgroup->{'max_referenced'}) ?
			$qgroup->{'max_referenced'} : 0, 1));
print &ui_table_row($text{'btrfs_max_exclusive'},
	&quota_input("max_exclusive",
		defined($qgroup->{'max_exclusive'}) ?
			$qgroup->{'max_exclusive'} : 0, 1));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'btrfs_update'} ] ]);

# Return to the qgroup list for this filesystem.
&ui_print_footer("list_btrfs.cgi?dir=".&urlize($dir), $text{'btrfs_title'});
