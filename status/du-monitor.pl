# du-monitor.pl
# Check disk usage in some directory

sub get_du_status
{
local $used = &disk_usage_kb($_[0]->{'dir'}) * 1024;
if ($used > $_[0]->{'max'}) {
	return { 'up' => 0,
		 'desc' => &text('du_over', &nice_size($used)) };
	}
else {
	return { 'up' => 1,
		 'desc' => &text('du_under', &nice_size($used)) };
	}
}

sub show_du_dialog
{
print &ui_table_row($text{'du_dir'},
	&ui_textbox("dir", $_[0]->{'dir'}, 60)." ".
	&file_chooser_button("dir", 1), 3);

print &ui_table_row($text{'du_max'},
	&ui_bytesbox("max", $_[0]->{'max'}));
}

sub parse_du_dialog
{
$in{'dir'} =~ /^\/\S*$/ || &error($text{'du_edir'});
-e $in{'dir'} || &error($text{'du_edir2'});
$_[0]->{'dir'} = $in{'dir'};
$in{'max'} =~ /^\d+$/ || &error($text{'du_emax'});
$_[0]->{'max'} = $in{'max'} * $in{'max_units'};
}

