# log_parser.pl
# Functions for parsing this module's logs

do 'iscsi-server-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'extent' || $type eq 'device' || $type eq 'target' ||
    $type eq 'user') {
	return &text('log_'.$action.'_'.$type,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'extents' || $type eq 'devices' || $type eq 'targets' ||
       $type eq 'users') {
	return &text('log_'.$action.'_'.$type, $object);
	}
else {
	return $text{'log_'.$action};
	}
}

