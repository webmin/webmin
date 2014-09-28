# log_parser.pl
# Functions for parsing this module's logs

do 'iscsi-tgtd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "target" || $type eq "targets") {
	return &text('log_'.$action.'_'.$type, &html_escape($object));
	}
else {
	return $text{'log_'.$action};
	}
}

