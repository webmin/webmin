# change-monitor.pl
# Check if some file or directory has changed

sub get_change_status
{
local %change;
&read_file("$module_config_directory/change", \%change);
local $t = $change{$_[0]->{'file'}};
local @st = stat($_[0]->{'file'});
local $up;
if ($t && $st[9] != $t) {
	$up = 0;
	}
elsif (!$t) {
	$up = -1;
	}
else {
	$up = 1;
	}
$change{$_[0]->{'file'}} = $st[9];
&write_file("$module_config_directory/change", \%change);
return { 'up' => $up,
	 'value' => $st[9],
	 'nice_value' => &make_date($st[9]),
       };
}

sub show_change_dialog
{
print &ui_table_row($text{'change_file'},
	&ui_textbox("file", $_[0]->{'file'}, 30)." ".
	&file_chooser_button("file", 0), 3);
}

sub parse_change_dialog
{
$_[0]->{'file'} = $in{'file'};
}

