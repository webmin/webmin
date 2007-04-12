# log_parser.pl
# Functions for parsing this module's logs

do 'zones-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "net" || $type eq "fs" || $type eq "pkg" ||
    $type eq "rctl" || $type eq "attr" || $type eq "device") {
	# Some action on a zone attribute
	return &text('log_'.$action.'_'.$type,
		    "<tt>".&html_escape($object)."</tt>",
		    "<tt>".&html_escape($p->{'keyzone'})."</tt>");
	}
elsif ($type eq "zone") {
	# Some action on a zone itself
	return &text('log_'.$action.'_zone',
		    "<tt>".&html_escape($object)."</tt>");
	}
}

