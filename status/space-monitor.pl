# space-monitor.pl
# Check the free space on some filesystem

sub get_space_status
{
return { 'up' => -1 } if (!&foreign_check("mount", 1));
&foreign_require("mount", "mount-lib.pl");
local $m;
foreach $f (&mount::list_mounted()) {
	$m = $f if ($f->[0] eq $_[0]->{'fs'});
	}
if ($m) {
	local @sp = &mount::disk_space($m->[2], $m->[0]);
	if ($sp[1] < $_[0]->{'min'}) {
		return { 'up' => 0 };
		}

	if ($_[0]->{'inode'} && defined(&mount::inode_space)) {
		# Do the inode check too
		local @isp = &mount::inode_space($m->[2], $m->[0]);
		if ($isp[1] < $_[0]->{'inode'}) {
			return { 'up' => 0,
				 'desc' => &text('space_ierr', $isp[1]) };
			}
		}

	return { 'up' => 1,
		 'desc' => &text('space_desc', &nice_size($sp[1]*1024)) };
	}
else {
	return { 'up' => -1,
		 'desc' => $text{'space_nofs'} };
	}
}

sub show_space_dialog
{
if (&foreign_check("mount")) {
	# Can get filesystem list from mount module
	&foreign_require("mount", "mount-lib.pl");
	local @mounted = &mount::list_mounted();
	local ($got) = grep { $_->[0] eq $_[0]->{'fs'} } @mounted;
	print &ui_table_row($text{'space_fs'},
		&ui_select("fs", !$_[0]->{'fs'} ? $mounted[0]->[0] :
				 !$got ? "" : $_[0]->{'fs'},
			   [ (map { [ $_->[0] ] } @mounted),
			     [ "", $text{'space_other'} ] ])."\n".
		&ui_textbox("other", $got ? "" : $_[0]->{'fs'}, 30),
		3);
	}
else {
	# Just show text box
	print &ui_table_row($text{'space_fs'},
		&ui_textbox("other", $_[0]->{'fs'}, 30));
	}

print &ui_table_row($text{'space_min2'},
	&ui_bytesbox("min", $_[0]->{'min'}*1024));

if (defined(&mount::inode_space)) {
	print &ui_table_row($text{'space_inode'},
		&ui_textbox("inode", $_[0]->{'inode'}, 10));
	}
}

sub parse_space_dialog
{
&depends_check($_[0], "mount");
$in{'min'} =~ /^[0-9\.]+$/ || &error($text{'space_emin'});
$_[0]->{'min'} = $in{'min'}*$in{'min_units'}/1024;
if ($in{'fs'}) {
	$_[0]->{'fs'} = $in{'fs'};
	}
else {
	$in{'other'} =~ /^\// || &error($text{'space_eother'});
	$_[0]->{'fs'} = $in{'other'};
	}
if (defined($in{'inode'})) {
	$_[0]->{'inode'} = $in{'inode'} ? int($in{'inode'}) : undef;
	}
}

