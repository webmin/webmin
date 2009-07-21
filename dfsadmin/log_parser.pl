# log_parser.pl
# Functions for parsing this module's logs

do 'dfs-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'modify') {
	if ($p->{'old'} ne $p->{'directory'}) {
		return &text('log_rename',
			     "<tt>".&html_escape($p->{'old'})."</tt>",
			     "<tt>".&html_escape($p->{'directory'})."</tt>");
		}
	else {
		return &text('log_modify',
			     "<tt>".&html_escape($object)."</tt>");
		}
	}
elsif ($action eq 'create') {
	return &text('log_create', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'delete') {
	return &text('log_delete', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'apply') {
	return $text{'log_apply'};
	}
else {
	return undef;
	}
}

