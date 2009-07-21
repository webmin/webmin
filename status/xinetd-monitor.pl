# xinetd-monitor.pl
# Monitor xinetd on this host

sub get_xinetd_status
{
local %xconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $xconfig{'xinetd_conf'});
&foreign_require($_[1], "xinetd-lib.pl");
if (&xinetd::is_xinetd_running()) {
	local @st = stat($xconfig{'pid_file'});
	return { 'up' => 1,
		 'desc' => @st ? &text('up_since', scalar(localtime($st[9])))
			       : undef };
	}
return { 'up' => 0 };
}

sub parse_xinetd_dialog
{
&depends_check($_[0], "xinetd");
}

1;

