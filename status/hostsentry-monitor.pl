# hostsentry-monitor.pl
# Monitor the hostsentry daemon

# Check the PID file to see if hostsentry is running
sub get_hostsentry_status
{
return { 'up' => -1 } if (!&foreign_check("sentry"));
local %sconfig = &foreign_config("sentry");
-r $sconfig{'hostsentry'} || return { 'up' => -1 };
&foreign_require("sentry", "sentry-lib.pl");
local $pid = &sentry::get_hostsentry_pid();
if ($pid) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_hostsentry_dialog
{
&depends_check($_[0], "sentry");
}

1;

