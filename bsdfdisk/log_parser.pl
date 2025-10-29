# log_parser.pl
# Functions for parsing this module's logs

do 'bsdfdisk-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "slice" || $type eq "part" || $type eq "object") {
	return &text('log_'.$action.'_'.$type,
		     "<tt>".&html_escape($object)."</tt>");
	}
if ($type eq "disk") {
	return &text('log_'.$action.'_disk',
		     "<tt>".&html_escape($object)."</tt>");
	}
return undef;
}

1;
