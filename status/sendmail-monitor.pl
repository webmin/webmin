# sendmail-monitor.pl
# Monitor the sendmail server on this host

# Check the PID file to see if sendmail is running
sub get_sendmail_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "sendmail-lib.pl");
local %sconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $sconfig{'sendmail_cf'});
if (&sendmail::is_sendmail_running()) {
	local @pidfiles = split(/\t+/, $sconfig{'sendmail_pid'});
	local @st = stat($pidfiles[0]);
	return { 'up' => 1,
		 'desc' => @pidfiles ? 
			&text('up_since', scalar(localtime($st[9]))) : undef };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_sendmail_dialog
{
&depends_check($_[0], "sendmail");
}

1;

