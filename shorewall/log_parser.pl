# log_parser.pl
# Functions for parsing this module's logs

do 'shorewall-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'table' || $type eq 'comment') {
	return &text('log_'.$action.'_'.$type, $text{$object.'_title'});
	}
else {
	return $text{'log_'.$action};
	}
}


