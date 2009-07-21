# exec-monitor.pl
# Check if some command exits with non-zero status

sub get_exec_status
{
system("($_[0]->{'cmd'}) >/dev/null 2>&1 </dev/null");
return { 'up' => $?==0 ? 1 : 0 };
}

sub show_exec_dialog
{
print &ui_table_row($text{'exec_cmd'},
	&ui_textbox("cmd", $_[0]->{'cmd'}, 50), 3);
}

sub parse_exec_dialog
{
$in{'cmd'} || &error($text{'exec_ecmd'});
$_[0]->{'cmd'} = $in{'cmd'};
}

