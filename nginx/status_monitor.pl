
use strict;
use warnings;
do 'nginx-lib.pl';
our (%text, %config);

# status_monitor_list()
# Just one type is supported
sub status_monitor_list
{
return ( [ "nginx", $text{'monitor_type'} ] );
}

# status_monitor_status(type, &monitor, from-ui)
# Check if Nginx is running
sub status_monitor_status
{
if (!-r $config{'nginx_config'} ||
    !&has_command($config{'nginx_cmd'})) {
	return { 'up' => -1,
		 'desc' => $text{'monitor_missing'} };
	}
my $pid = is_nginx_running();
if ($pid) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

# status_monitor_actions(type, &monitor, up)
# Returns permitted stop/apply actions when running, or start when stopped
sub status_monitor_actions
{
my ($type, $s, $up) = @_;
our (%access, %text);
# Only offer controls to users allowed to manage Nginx
return ( ) if ($type ne 'nginx' || !$access{'stop'});
return $up ? ( [ 'stop', $text{'index_stop'}, 'stop.cgi' ],
	       [ 'restart', $text{'index_restart'}, 'restart.cgi' ] ) :
	     ( [ 'start', $text{'index_start'}, 'start.cgi' ] );
}

1;

