# postfix-monitor.pl
# Monitor the postfix server on this host

# Check to see if postfix is running
sub get_postfix_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "postfix-lib.pl");
local %pconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $pconfig{'postfix_control_command'});
if (&foreign_call($_[1], "is_postfix_running")) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_postfix_dialog
{
&depends_check($_[0], "postfix");
}

1;

