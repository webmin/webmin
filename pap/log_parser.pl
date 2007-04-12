# log_parser.pl
# Functions for parsing this module's logs

do 'pap-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'mgetty') {
	return &text('log_mgetty_'.$action,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'dialin') {
	return &text('log_dialin_'.$action,
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'options') {
	return $object ne '-' ?
		&text('log_options2', "<tt>".&html_escape($object)."</tt>") :
		$text{'log_options'};
	}
elsif ($action eq 'sync') {
	return $text{'log_sync'};
	}
elsif ($action eq 'mgetty_apply') {
	return $text{'log_apply'};
	}
elsif ($action eq 'deletes') {
	return &text('log_deletes', $object);
	}
else {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
}

