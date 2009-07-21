# dnsadmin-monitor.pl
# Monitor the BIND 4 DNS server on this host

# Check the PID file to see if BIND is running
sub get_dnsadmin_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "dns-lib.pl");
local %dconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $dconfig{'named_boot_file'});
if (open(PID, $dconfig{'named_pid_file'}) && <PID> =~ /(\d+)/ && kill(0, $1)) {
	close(PID);
	local @st = stat($dconfig{'named_pid_file'});
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_dnsadmin_dialog
{
&depends_check($_[0], "dnsadmin");
}

1;

