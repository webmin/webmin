# apache-monitor.pl
# Monitor the apache server on this host

# Check the PID file to see if apache is running
sub get_apache_status
{
my ($serv, $mod) = @_;
return { 'up' => -1 } if (!&foreign_check($mod));
&foreign_require($mod, "apache-lib.pl");
return { 'up' => -1 } if (!&foreign_check($mod));
local %aconfig = &foreign_config($mod);
return { 'up' => -1 } if (!-x $aconfig{'httpd_path'});

if (&foreign_call($mod, "is_apache_running")) {
	local $pidfile = &foreign_call($mod, "get_pid_file");
	local @st = stat($pidfile);
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_apache_dialog
{
&depends_check($_[0], "apache");
}

1;

