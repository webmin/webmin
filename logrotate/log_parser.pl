# log_parser.pl
# Functions for parsing this module's logs

do 'logrotate-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'sched') {
	return $text{'log_'.$action.'_sched'};
	}
elsif ($type eq 'global') {
	return $text{'log_global'};
	}
elsif ($type eq 'logs') {
	return &text('log_'.$action.'_logs', $object);
	}
elsif ($type eq 'log') {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
}

