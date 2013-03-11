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
else {
	return $text{'log_'.$action};
	}
}

