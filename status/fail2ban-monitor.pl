# fail2ban-monitor.pl
# Monitor the fail2ban server on this host

# Check to see if fail2ban is running
sub get_fail2ban_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "fail2ban-lib.pl");
local %pconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (&foreign_call($_[1], "check_fail2ban"));
if (&foreign_call($_[1], "is_fail2ban_running")) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_fail2ban_dialog
{
&depends_check($_[0], "fail2ban");
}

1;

