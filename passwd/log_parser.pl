# log_parser.pl
# Functions for parsing this module's logs

do 'passwd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'passwd') {
	return &text('log_passwd', "<tt>".&html_escape($object)."</tt>");
	}
else {
	return undef;
	}
}

