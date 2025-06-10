# log_parser.pl
# Functions for parsing this module's logs

do 'minecraft-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($object eq 'backup') {
	return &text('log_'.$action.'_backup', $object);
	}
elsif ($action eq 'changeversion' || $action eq 'addversion') {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
else {
	return $text{'log_'.$action};
	}
}

