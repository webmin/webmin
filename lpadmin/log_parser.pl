# log_parser.pl
# Functions for parsing this module's logs

do 'lpadmin-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'cancel') {
	return &text("log_cancel_${type}",
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'id'})."</tt>");
	}
elsif ($action eq 'cancelsel') {
	return &text("log_cancel_sel", "<tt>".&html_escape($object)."</tt>",
		     $p->{'d'});
	}
elsif ($action eq 'stop') {
	return $text{'log_stop'};
	}
elsif ($action eq 'start') {
	return $text{'log_start'};
	}
elsif ($action eq 'restart') {
	return $text{'log_restart'};
	}
elsif ($type eq 'printer') {
	return &text($long && $p->{'mode'} ? "log_${action}_l" : "log_$action",
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'dest'})."</tt>",
		     &html_escape($p->{'driver'}));
	}
else {
	return undef;
	}
}

