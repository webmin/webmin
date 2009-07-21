# portsentry-monitor.pl
# Monitor the portsentry daemon

# Check the PID file to see if portsentry is running
sub get_portsentry_status
{
return { 'up' => -1 } if (!&foreign_check("sentry"));
local %sconfig = &foreign_config("sentry");
&has_command($sconfig{'portsentry'}) || return { 'up' => -1 };
&foreign_require("sentry", "sentry-lib.pl");
local @pids = &sentry::get_portsentry_pids();
if (@pids) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_portsentry_dialog
{
&depends_check($_[0], "sentry");
}

1;

