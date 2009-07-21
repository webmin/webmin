# cfengine-monitor.pl
# Monitor the cfengine daemon on this host

# Check the PID file to see if cfd is running
sub get_cfengine_status
{
local %cconfig = &foreign_config($_[1]);
&has_command($cconfig{'cfd'}) || return { 'up' => -1 };
local @pids = &find_byname("cfd");
if (@pids) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_cfengine_dialog
{
&depends_check($_[0], "cfengine");
}

1;

