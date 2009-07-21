# dhcpd-monitor.pl
# Monitor the DHCP server on this host

# Check the PID file to see if DHCPd is running
sub get_dhcpd_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "dhcpd-lib.pl");
local %dconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $dconfig{'dhcpd_conf'});
if (&foreign_call($_[1], "is_dhcpd_running")) {
	local @st = stat($dconfig{'pid_file'});
	return { 'up' => 1,
		 'desc' => @st ? &text('up_since', scalar(localtime($st[9])))
			       : undef };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_dhcpd_dialog
{
&depends_check($_[0], "dhcpd");
}

1;

