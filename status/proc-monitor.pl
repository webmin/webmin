# proc-monitor.pl
# Check if some process is running

sub get_proc_status
{
local (@found, $count);
return { 'up' => -1 } if (!&foreign_check("proc"));
&foreign_require("proc", "proc-lib.pl");
foreach $p (&foreign_call("proc", "list_processes")) {
	if ($p->{'args'} =~ /$_[0]->{'cmd'}/i) {
		push(@found, $p->{'pid'});
		$count++;
		}
	}
local $thresh = $_[0]->{'thresh'} || 1;
if ($_[0]->{'not'}) {
	if ($count >= $thresh) {
		return { 'up' => 0 };
		}
	else {
		return { 'up' => 1 };
		}
	}
else {
	if ($count >= $thresh) {
		return { 'up' => 1, 'desc' => &text('proc_pid',
						    join(" ", @found)) };
		}
	else {
		return { 'up' => 0 };
		}
	}
}

sub show_proc_dialog
{
print &ui_table_row($text{'proc_cmd'},
	&ui_textbox("cmd", $_[0]->{'cmd'}, 30));

print &ui_table_row($text{'proc_not'},
	&ui_radio("not", int($_[0]->{'not'}),
		  [ [ 0, $text{'proc_not0'} ],
		    [ 1, $text{'proc_not1'} ] ]));

print &ui_table_row($text{'proc_thresh'},
	&ui_textbox("thresh", $_[0]->{'thresh'} || 1, 5));
}

sub parse_proc_dialog
{
&depends_check($_[0], "proc");
$in{'cmd'} || &error($text{'proc_ecmd'});
$_[0]->{'cmd'} = $in{'cmd'};
$_[0]->{'not'} = $in{'not'};
$in{'thresh'} =~ /^\d+$/ || &error($text{'proc_ethresh'});
$_[0]->{'thresh'} = $in{'thresh'};
}

1;

