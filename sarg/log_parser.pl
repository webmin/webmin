# log_parser.pl
# Functions for parsing this module's logs

do 'sarg-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq "sched") {
	return $text{'webmin_log_'.$action.'_'.$object};
	}
else {
	return $text{'webmin_log_'.$action};
	}
}

