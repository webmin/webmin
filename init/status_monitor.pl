do 'init-lib.pl';

# status_monitor_actions(type, &monitor, up)
# Returns permitted init service actions for the given status
sub status_monitor_actions
{
my ($type, $s, $up) = @_;
# Require service-control permission and a saved service name
return ( ) if ($type ne 'init' || !$access{'bootup'} || !$s->{'action'});
return map { [ $_, $text{'index_'.$_}, 'monitor_action.cgi',
	       { 'name' => $s->{'action'}, 'action' => $_ } ] }
	   ($up ? ( 'stop', 'restart' ) : ( 'start' ));
}

1;
