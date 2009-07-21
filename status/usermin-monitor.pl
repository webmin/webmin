# usermin-monitor.pl
# Monitor the usermin server on this host

# Check the PID file to see if usermin is running
sub get_usermin_status
{
local %uconfig = &foreign_config($_[1]);
local %miniserv;
&read_file("$uconfig{'usermin_dir'}/miniserv.conf", \%miniserv) ||
	return { 'up' => -1 };
if (open(PID, $miniserv{'pidfile'}) && chop($pid = <PID>) && kill(0, $pid)) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_mon_dialog
{
&depends_check($_[0], "usermin");
}

1;

