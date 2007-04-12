# log_parser.pl
# Functions for parsing this module's logs

do 'cluster-cron-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'exec') {
	local @server = split(/\0/, $p->{'run'});
	if ($long) {
		return &text('log_run_l', "<tt>$p->{'cluster_command'}</tt>",
		     join(", ", map { $_ ? "<tt>$_</tt>"
					 : $text{'index_this'} } @server));
		}
	else {
		return &text('log_run', "<tt>$p->{'cluster_command'}</tt>",
					scalar(@server));
		}
	}
elsif ($action eq 'deletes') {
	return &text('log_deletes', $object);
	}
else {
	local $l = $long ? "_l" : "";
	return &text("log_${action}${l}", "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'cluster_command'})."</tt>");
	}
}

