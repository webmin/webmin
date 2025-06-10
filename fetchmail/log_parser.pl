# log_parser.pl
# Functions for parsing this module's logs

do 'fetchmail-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'poll') {
	if ($p->{'user'}) {
		return &text("log_${action}_poll_user",
			     "<tt>".&html_escape($object)."</tt>",
			     "<tt>".&html_escape($p->{'user'})."</tt>");
		}
	else {
		return &text("log_${action}_poll_file",
			     "<tt>".&html_escape($object)."</tt>",
			     "<tt>".&html_escape($p->{'file'})."</tt>");
		}
	}
elsif ($type eq 'cron') {
	return $text{"log_${action}_cron"};
	}
elsif ($action eq 'check') {
	if ($object =~ /^\//) {
		return &text("log_check_file_${type}",
			     "<tt>".&html_escape($object)."</tt>",
			     "<tt>".&html_escape($p->{'poll'})."</tt>");
		}
	else {
		return &text("log_check_user_${type}",
			     "<tt>".&html_escape($object)."</tt>",
			     "<tt>".&html_escape($p->{'poll'})."</tt>");
		}
	}
elsif ($action eq 'global') {
	return &text($object =~ /^\// ? "log_global_file" : "log_global_user",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'start') {
	return &text('log_start', $p->{'interval'});
	}
elsif ($action eq 'stop') {
	return $text{'log_stop'};
	}
else {
	return undef;
	}
}

