# log_parser.pl
# Functions for parsing this module's logs

do 'file-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'export' || $type eq 'share') {
	return &text("log_${action}_${type}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'save' || $action eq 'chmod' || $action eq 'mkdir' ||
       $action eq 'upload' || $action eq 'delete') {
	return &text("log_${action}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'link' || $action eq 'move' || $action eq 'copy') {
	return &text("log_${action}",
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'to'})."</tt>");
	}
elsif ($action eq 'relink') {
	return &text('log_relink',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'linkto'})."</tt>");
	}
elsif ($action eq 'rename') {
	return &text('log_move',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'new'})."</tt>");
	}
elsif ($action eq 'attr') {
	return &text('log_attr', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'acl') {
	return &text('log_acl', "<tt>".&html_escape($object)."</tt>");
	}
else {
	return undef;
	}
}

