# log_parser.pl
# Functions for parsing this module's logs

do 'inittab-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'modify' && $p->{'oldid'} ne $object) {
	return &text('log_modify', "<tt>$p->{'oldid'}</tt>",
				   "<tt>$object</tt>");
	}
elsif ($action eq 'modify') {
	return &text('log_modify', "<tt>$object</tt>");
	}
elsif ($action eq 'create') {
	return &text('log_create', "<tt>$object</tt>");
	}
elsif ($action eq 'delete') {
	if ($type eq 'inittabs') {
		return &text('log_deletes', "<tt>$object</tt>");
		}
	else {
		return &text('log_delete', "<tt>$object</tt>");
		}
	}
elsif ($action eq 'apply') {
	return $text{'log_apply'};
	}
else {
	return undef;
	}
}

