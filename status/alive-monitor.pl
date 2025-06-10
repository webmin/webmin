# alive-monitor.pl
# Always returns OK - useful for remote monitoring

sub get_alive_status
{
local $out = &backquote_command("uptime 2>/dev/null");
return { 'up' => 1,
	 'desc' => $out =~ /\s+up\s+([^,]+),/ ? &text('alive_up', "$1")
					      : undef };
}



