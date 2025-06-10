# log_parser.pl
# Functions for parsing this module's logs

do 'postfix-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'delete' || $action eq 'modify' || $action eq 'create') {
	return &text("log_${type}_${action}",
		     "<tt>".&html_escape($object)."</tt>") ||
	       &text("log_${action}_$type", $object);
	}
elsif ($action eq 'manual') {
	return &text('log_manual', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'delqs') {
	return &text('log_delqs', $object);
	}
elsif ($action eq 'backend') {
	return &text('log_backend', $object);
	}
else {
	return $text{'log_'.$action};
	}
}

