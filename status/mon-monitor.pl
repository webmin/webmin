# mon-monitor.pl
# Monitor the mon daemon on this host

# Check the PID file to see if mon is running
sub get_mon_status
{
local %mconfig = &foreign_config($_[1]);
-d $mconfig{'cfbasedir'} || return { 'up' => -1 };
local $pid;
if (open(PID, $mconfig{'pid_file'}) && chop($pid = <PID>) && kill(0, $pid)) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_mon_dialog
{
&depends_check($_[0], "mon");
}

1;

