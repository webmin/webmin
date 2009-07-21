# webmin-monitor.pl
# Monitor the webmin server on this host

# Check the PID file to see if webmin is running
sub get_webmin_status
{
local %miniserv;
&get_miniserv_config(\%miniserv);
if (open(PID, $miniserv{'pidfile'}) && chop($pid = <PID>) && kill(0, $pid)) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_webmin_dialog
{
}

1;

