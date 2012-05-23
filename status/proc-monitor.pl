# proc-monitor.pl
# Check if some process is running

sub get_proc_status
{
local (@found, $count);
return { 'up' => -1 } if (!&foreign_check("proc"));
&foreign_require("proc", "proc-lib.pl");
foreach $p (&foreign_call("proc", "list_processes")) {
	if (eval { $p->{'args'} =~ /$_[0]->{'cmd'}/i } &&
	    (!$_[0]->{'asuser'} || $_[0]->{'asuser'} eq $p->{'user'})) {
		push(@found, $p->{'pid'});
		$count++;
		}
	}
local $thresh = $_[0]->{'thresh'} || 1;
if ($_[0]->{'not'}) {
	if ($count >= $thresh) {
		return { 'up' => 0, 'value' => $count };
		}
	else {
		return { 'up' => 1, 'value' => $count };
		}
	}
else {
	if ($count >= $thresh) {
		return { 'up' => 1,
			 'desc' => &text('proc_pid', join(" ", @found)),
			 'value' => $count };
		}
	else {
		return { 'up' => 0, 'value' => $count };
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

print &ui_table_row($text{'proc_asuser'},
	&ui_opt_textbox("asuser", $_[0]->{'asuser'}, 13,
			$text{'proc_anyuser'})." ".
	&user_chooser_button("asuser"));
}

sub parse_proc_dialog
{
&depends_check($_[0], "proc");
$in{'cmd'} || &error($text{'proc_ecmd'});
$_[0]->{'cmd'} = $in{'cmd'};
$_[0]->{'not'} = $in{'not'};
$in{'thresh'} =~ /^\d+$/ || &error($text{'proc_ethresh'});
$_[0]->{'thresh'} = $in{'thresh'};
if ($in{'asuser_def'}) {
	delete($_[0]->{'asuser'});
	}
else {
	defined(getpwnam($in{'asuser'})) || &error($text{'proc_easuser'});
	$_[0]->{'asuser'} = $in{'asuser'};
	}
}

1;

