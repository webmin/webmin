# log_parser.pl
# Functions for parsing this module's logs

do 'pptp-server-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
$object = "<tt>".&html_escape($object)."</tt>";
if ($type eq 'secret') {
	return &text('log_secret_'.$action, $object);
	}
else {
	return &text('log_'.$action, $object);
	}
}

