# log_parser.pl
# Functions for parsing this module's logs

do 'iscsi-client-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "connection") {
	return &text('log_'.$action.'_'.$type, &html_escape($p->{'host'}),
					       &html_escape($p->{'target'}));
	}
elsif ($type eq "connections") {
	return &text('log_'.$action.'_'.$type, $object);
	}
elsif ($type eq "iface") {
	return &text('log_'.$action.'_'.$type, &html_escape($object));
	}
elsif ($type eq "ifaces") {
	return &text('log_'.$action.'_'.$type, $object);
	}
else {
	return $text{'log_'.$action};
	}
}

