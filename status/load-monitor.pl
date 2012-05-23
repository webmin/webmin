# load-monitor.pl
# Check if the system load exceeds some level

sub get_load_status
{
local @u = &uptime_output();
if (!@u) {
	return { 'up' => -1 }
	}
elsif ($u[$_[0]->{'time'}] >= $_[0]->{'max'}) {
	return { 'up' => 0,
		 'value' => $u[$_[0]->{'time'}] };
	}
else {
	return { 'up' => 1,
		 'desc' => "Load is $u[$_[0]->{'time'}]",
		 'value' => $u[$_[0]->{'time'}] };
	}
}

sub show_load_dialog
{
print &ui_table_row($text{'load_time'},
	&ui_radio("time", int($_[0]->{'time'}),
		  [ [ 0, $text{'load_1'} ],
		    [ 1, $text{'load_5'} ],
		    [ 2, $text{'load_15'} ] ]));

print &ui_table_row($text{'load_max'},
	&ui_textbox("max", $_[0]->{'max'}, 6));
}

sub parse_load_dialog
{
&has_command("uptime") || &error($text{'load_ecmd'});
scalar(&uptime_output()) || &error($text{'load_efmt'});
$in{'max'} =~ /^[0-9\.]+$/ || &error($text{'load_emax'});
$_[0]->{'time'} = $in{'time'};
$_[0]->{'max'} = $in{'max'};
}

sub uptime_output
{
local $out = `uptime 2>&1`;
return $out =~ /average(s)?:\s+([0-9\.]+),?\s+([0-9\.]+),?\s+([0-9\.]+)/i ?
		( $2, $3, $4 ) : ( );
}

