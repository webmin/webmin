# log_parser.pl
# Functions for parsing this module's logs

do 'dhcpd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'apply') {
	return $text{'log_apply'};
	}
elsif ($action eq 'start') {
	return $text{'log_start'};
	}
elsif ($action eq 'stop') {
	return $text{'log_stop'};
	}
elsif ($type eq 'subnet' || $type eq 'shared' || $type eq 'host') {
	return &text("log_${action}_${type}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'group') {
	local @h = split(/,/, $object);
	return &text("log_${action}_group", scalar(@h));
	}
elsif ($type eq 'subnets' || $type eq 'hosts') {
	return &text("log_${action}_${type}", $object);
	}
elsif ($type eq 'lease' && $action eq 'delete') {
	return &text('log_delete_lease',
		     "<tt>".&html_escape($object)."</tt>");
	}
else {
	return undef;
	}
}

