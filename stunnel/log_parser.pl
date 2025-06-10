# log_parser.pl
# Functions for parsing this module's logs

do 'stunnel-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'stunnel') {
	return &text("log_$action", "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'stunnels') {
	return &text("log_${action}_stunnels", $object);
	}
else {
	return $text{"log_$action"};
	}
return undef;
}

