# log_parser.pl
# Functions for parsing this module's logs

do 'inetd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'apply') {
	return $text{'log_apply'};
	}
elsif ($type eq 'serv') {
	local $msg = $p->{'prog'} ? "log_${action}_prog"
				  : "log_${action}_serv";
	$msg .= "_l" if ($long);
	return &text($msg, "<tt>$object</tt>", "<tt>$p->{'port'}</tt>",
		     "<tt>".&html_escape($p->{'prog'})."</tt>");
	}
elsif ($type eq 'rpc') {
	local $msg = $p->{'prog'} ? "log_${action}_rprog"
				  : "log_${action}_rpc";
	$msg .= "_l" if ($long);
	return &text($msg, "<tt>$object</tt>", "<tt>$p->{'number'}</tt>",
		     "<tt>".&html_escape($p->{'prog'})."</tt>");
	}
else {
	return undef;
	}
}

