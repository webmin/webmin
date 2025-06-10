# oldfile-monitor.pl
# Check if some file has not been changed lately

sub get_oldfile_status
{
local %change;
local @st = stat($_[0]->{'file'});
if (!@st) {
	# File doesn't exist!
	return { 'up' => -1 };
	}
elsif ($st[9] < time()-$_[0]->{'diff'}) {
	# File hasn't been changed lately
	return { 'up' => 0,
		 'value' => $st[9],
		 'nice_value' => &make_date($st[9]) };
	}
else {
	# File has been changed lately
	return { 'up' => 1,
		 'value' => $st[9],
		 'nice_value' => &make_date($st[9]) };
	}
}

sub show_oldfile_dialog
{
print &ui_table_row($text{'oldfile_file'},
	&ui_textbox("file", $_[0]->{'file'}, 50)." ".
	&file_chooser_button("file", 0), 3);

print &ui_table_row($text{'oldfile_diff'},
	&ui_textbox("diff", $_[0]->{'diff'}, 10)." ".$text{'oldfile_secs'});
}

sub parse_oldfile_dialog
{
$_[0]->{'file'} = $in{'file'};
$_[0]->{'diff'} = $in{'diff'};
}

