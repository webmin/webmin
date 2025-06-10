# log_parser.pl
# Functions for parsing this module's logs

do 'status-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "template" && $action eq "deletes") {
	return &text("log_tmpl_deletes", $object);
	}
elsif ($type eq "template") {
	return &text("log_tmpl_${action}",
		     "<i>".&html_escape($p->{'desc'})."</i>");
	}
elsif ($action eq "deletes") {
	return &text("log_deletes", $object);
	}
else {
	return &text("log_${action}", "<i>".&html_escape($p->{'desc'})."</i>");
	}
}

