# log_parser.pl
# Functions for parsing this module's logs

do 'fsdump-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'create' || $action eq 'modify' ||
    $action eq 'delete' || $action eq 'kill') {
	return &text("log_$action", "<tt>".&html_escape($p->{'dir'})."</tt>");
	}
elsif ($action eq 'backup' || $action eq 'bgbackup') {
	return &text('log_'.$action, "<tt>".&html_escape($p->{'dir'})."</tt>",
				   "<tt>".&dump_dest($p)."</tt>");
	}
elsif ($action eq 'restore') {
	return &text('log_restore', "<tt>".&html_escape($object)."</tt>");
	}
else {
	return undef;
	}
}

