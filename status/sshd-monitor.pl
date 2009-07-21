# sshd-monitor.pl
# Monitor the SSH server on this host

# Check the PID file to see if sshd is running
sub get_sshd_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "sshd-lib.pl");
return { 'up' => -1 } if (!&foreign_check($_[1]));
local %sconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $sconfig{'sshd_config'});
local $conf = &foreign_call($_[1], "get_sshd_config");
local $pidfile = &foreign_call($_[1], "find_value", "PidFile", $conf);
$pidfile ||= $sconfig{'pid_file'};
if (open(PID, $pidfile) && <PID> =~ /(\d+)/ && kill(0, $1)) {
	close(PID);
	local @st = stat($pidfile);
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_sshd_dialog
{
&depends_check($_[0], "sshd");
}

1;

