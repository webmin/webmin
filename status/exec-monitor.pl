# exec-monitor.pl
# Check if some command exits with non-zero status

sub get_exec_status
{
my $re = $_[0]->{'regexp'};
if ($re ne '') {
	# Get output and compare
	my $out = &backquote_logged("($_[0]->{'cmd'}) 2>&1 </dev/null");
	if ($_[0]->{'remode'} == 0 && $out !~ /$re/) {
		return { 'up' => 0 };
		}
	elsif ($_[0]->{'remode'} == 1 && $out =~ /$re/) {
		return { 'up' => 0 };
		}
	}
else {
	# Just get exit status
	&system_logged("($_[0]->{'cmd'}) >/dev/null 2>&1 </dev/null");
	}
if ($_[0]->{'mode'} == 0) {
	return { 'up' => $? == 0 ? 1 : 0 };
	}
elsif ($_[0]->{'mode'} == 1) {
	return { 'up' => $? == 0 ? 0 : 1 };
	}
else {
	return { 'up' => 1 };
	}
}

sub show_exec_dialog
{
print &ui_table_row($text{'exec_cmd'},
	&ui_textbox("cmd", $_[0]->{'cmd'}, 70), 3);

print &ui_table_row($text{'exec_mode'},
	&ui_radio("mode", $_[0]->{'mode'} || 0,
		  [ [ 0, $text{'exec_mode0'} ],
		    [ 1, $text{'exec_mode1'} ],
		    [ 2, $text{'exec_mode2'} ] ]), 3);

print &ui_table_row($text{'exec_regexp'},
	&ui_opt_textbox("regexp", $_[0]->{'regexp'}, 60, $text{'exec_noregexp'}), 3);

print &ui_table_row($text{'exec_remode'},
	&ui_radio("remode", $_[0]->{'remode'} || 0,
		  [ [ 0, $text{'exec_remode0'} ],
		    [ 1, $text{'exec_remode1'} ] ]), 3);
}

sub parse_exec_dialog
{
$in{'cmd'} || &error($text{'exec_ecmd'});
$_[0]->{'cmd'} = $in{'cmd'};
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'regexp'} = $in{'regexp_def'} ? undef : $in{'regexp'};
$_[0]->{'remode'} = $in{'remode'};
}

