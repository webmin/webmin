do 'firewalld-lib.pl';

# status_monitor_actions(type, &monitor, up)
# Returns FirewallD actions for the given status. The module CGIs also
# restart dependent services when starting or applying the firewall.
sub status_monitor_actions
{
my ($type, $s, $up) = @_;
# Only the built-in FirewallD monitor is supported
return ( ) if ($type ne 'firewalld');
return $up ? ( [ 'stop', $text{'index_stop'}, 'stop.cgi' ],
	       [ 'restart', $text{'index_restart_firewalld'},
		 'restart.cgi' ] ) :
	     ( [ 'start', $text{'index_start'}, 'start.cgi' ] );
}

1;
