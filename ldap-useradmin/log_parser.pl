# log_parser.pl
# Functions for parsing this module's logs

do 'ldap-useradmin-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
$object = &html_escape($object);
if ($type eq 'user') {
	if ($action eq 'modify' && $p->{'old'} ne $object) {
		return &text('log_urename',
			     "<tt>".&html_escape($p->{'old'})."</tt>",
			     "<tt>$object</tt>");
		}
	elsif ($action eq 'modify') {
		return &text('log_umodify', "<tt>$object</tt>");
		}
	elsif ($action eq 'create') {
		return &text('log_ucreate', "<tt>$object</tt>");
		}
	elsif ($action eq 'delete' && $p->{'delhome'}) {
		return &text('log_udeletehome', "<tt>$object</tt>",
			     "<tt>".&html_escape($p->{'home'})."</tt>");
		}
	elsif ($action eq 'delete') {
		return &text('log_udelete', "<tt>$object</tt>");
		}
	}
elsif ($type eq 'group') {
	if ($action eq 'modify') {
		return &text('log_gmodify', "<tt>$object</tt>");
		}
	elsif ($action eq 'create') {
		return &text('log_gcreate', "<tt>$object</tt>");
		}
	elsif ($action eq 'delete') {
		return &text('log_gdelete', "<tt>$object</tt>");
		}
	}
elsif ($action eq 'batch') {
	if ($object =~ /^\//) {
		return &text($long ? 'log_batch_l' : 'log_batch',
			     "<tt>$object</tt>", $p->{'created'},
			     $p->{'modified'}, $p->{'deleted'});
		}
	else {
		return &text($long ? 'log_ubatch_l' : 'log_ubatch',
			     $p->{'created'}, $p->{'modified'},$p->{'deleted'});
		}
	}
return undef;
}
