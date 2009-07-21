# log_parser.pl
# Functions for parsing this module's logs

do 'mount-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq "swap") {
	return &text('log_swap', "<tt>".&html_escape($object)."</tt>");
	}
else {
	local $text = $long ? "log_${action}_l" : "log_${action}";
	return &text($text, "<tt>".&html_escape($p->{'dev'})."</tt>",
			    &fstype_name($p->{'type'}),
			    "<tt>".&html_escape($p->{'dir'})."</tt>");
	}
}

