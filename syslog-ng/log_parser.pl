# log_parser.pl
# Functions for parsing this module's logs

do 'syslog-ng-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'source' || $type eq 'destination' ||
    $type eq 'filter' || $type eq 'log') {
	return &text('log_'.$action.'_'.$type,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'sources' || $type eq 'destinations' ||
       $type eq 'filters' || $type eq 'logs') {
	return &text('log_'.$action.'_'.$type, $object);
	}
else {
	return $text{'log_'.$action};
	}
}

