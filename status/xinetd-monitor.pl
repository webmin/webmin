# xinetd-monitor.pl
# Monitor xinetd on this host

sub get_xinetd_status
{
local %xconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $xconfig{'xinetd_conf'});
if (open(PID, $xconfig{'pid_file'}) && <PID> =~ /(\d+)/ && kill(0, $1)) {
	close(PID);
	local @st = stat($xconfig{'pid_file'});
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
return { 'up' => 0 };
}

sub parse_xinetd_dialog
{
&depends_check($_[0], "xinetd");
}

1;

