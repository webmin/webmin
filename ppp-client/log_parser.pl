# log_parser.pl
# Functions for parsing this module's logs

do 'ppp-client-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "dialer") {
	return &text('log_'.$action,
		     "<tt>".&html_escape(&dialer_name($object))."</tt>");
	}
elsif ($action eq "init") {
	return $text{'log_init'};
	}
elsif ($action eq "connect") {
	return &text($object && $object ne '-' ? 'log_connect' : 'log_fail',
		     "<tt>".&html_escape($type)."</tt>");
	}
elsif ($action eq "disconnect") {
	return &text('log_disconnect', "<tt>".&html_escape($type)."</tt>");
	}
else {
	return undef;
	}
}

