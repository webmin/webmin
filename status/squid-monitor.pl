# squid-monitor.pl
# Monitor the squid server on this host

# Check the PID file to see if squid is running
sub get_squid_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "squid-lib.pl");
return { 'up' => -1 } if (!&foreign_check($_[1]));
local %sconfig = &foreign_config($_[1]);
return { 'up' => -1 } if (!-r $sconfig{'squid_conf'});
local $conf = &foreign_call($_[1], "get_config");
local $str = &foreign_call($_[1], "find_config", "pid_filename", $conf);
local $file;
if ($str) {
	$file = $str->{'values'}->[0];
	}
else {
	$file = $sconfig{'pid_file'};
	}
if (open(PID, $file) && <PID> =~ /(\d+)/ && kill(0, $1)) {
	close(PID);
	local @st = stat($file);
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_squid_dialog
{
&depends_check($_[0], "squid");
}

1;

