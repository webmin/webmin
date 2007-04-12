# qmailadmin-monitor.pl
# Monitor the qmail server on this host

# Check the PID file to see if qmail is running
sub get_qmailadmin_status
{
local %qconfig = &foreign_config($_[1]);
-d $qconfig{'qmail_dir'} || return { 'up' => -1 };
local ($pid) = &find_byname("qmail-send");
if ($pid) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_qmailadmin_dialog
{
&depends_check($_[0], "qmailadmin");
}

1;

