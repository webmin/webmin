# log_parser.pl
# Functions for parsing this module's logs

do 'phpini-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq "imod") {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'mod'})."</tt>");
	}
elsif ($type eq "pkgs") {
	return &text('log_'.$action.'_pkgs', $object);
	}
else {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
}

