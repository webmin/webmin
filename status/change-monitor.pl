# change-monitor.pl
# Check if some file or directory has changed

sub get_change_status
{
local %change;
&read_file("$module_config_directory/change", \%change);
local $t = $change{$_[0]->{'file'}};
local @st = stat($_[0]->{'file'});
local $rv;
if ($t && $st[9] != $t) {
	$rv = { 'up' => 0 };
	}
elsif (!$t) {
	$rv = { 'up' => -1 };
	}
else {
	$rv = { 'up' => 1 };
	}
$change{$_[0]->{'file'}} = $st[9];
&write_file("$module_config_directory/change", \%change);
return $rv;
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

