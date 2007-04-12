# log_parser.pl
# Functions for parsing this module's logs

do 'time-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'remote') {
	local $tm = localtime($object);
	return &text($long ? "log_remote_${type}_l" : "log_remote_${type}",
	     "<i>$tm</i>", "<tt>".&html_escape($p->{'timeserver'})."</tt>");
	}
elsif ($action eq 'set') {
	local $tm = localtime($object);
	return &text("log_set_${type}", "<i>$tm</i>");
	}
elsif ($action eq 'sync') {
	return $text{'log_sync'};
	}
elsif ($action eq 'sync_s') {
	return $text{'log_sync_s'};
	}
elsif ($action eq 'timezone') {
	return &text('log_timezone', &html_escape($object));
	}
else {
	return undef;
	}
}

