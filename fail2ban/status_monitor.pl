do 'fail2ban-lib.pl';

# status_monitor_actions(type, &monitor, up)
# Returns stop/restart when running, or start when stopped
sub status_monitor_actions
{
my ($type, $s, $up) = @_;
# Only the built-in Fail2Ban monitor is supported
return ( ) if ($type ne 'fail2ban');
return $up ? ( [ 'stop', $text{'index_stop'}, 'stop.cgi' ],
	       [ 'restart', $text{'index_restart'}, 'restart.cgi' ] ) :
	     ( [ 'start', $text{'index_start'}, 'start.cgi' ] );
}

1;
