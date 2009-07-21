# log_parser.pl
# Functions for parsing this module's logs

do 'ldap-server-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'dn') {
	# Changed some DN
	$object =~ s/,\s+/,/g;
	return &text('log_'.$action.'_dn',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'dns') {
	# Multi-DN operation
	return &text('log_'.$action.'_dns', $object);
	}
elsif ($type eq 'attr') {
	# Changed some attribute of a DN
	$p->{'dn'} =~ s/,\s+/,/g;
	return &text($long ? 'log_'.$action.'_attr_l' : 'log_'.$action.'_attr',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'dn'})."</tt>",
		     "<tt>".&html_escape($p->{'value'})."</tt>");
	}
elsif ($type eq 'attrs') {
	# Multi-attribute operation
	$p->{'dn'} =~ s/,\s+/,/g;
	return &text('log_'.$action.'_attrs', $object,
		     "<tt>".&html_escape($p->{'dn'})."</tt>");
	}
elsif ($type eq 'access') {
	return &text('log_'.$action.'_access',
		     $object eq '*' ? $text{'log_all'} :
		     $object =~ /^dn(\.[^=]+)?=(.*)/ ?
			"<tt>".&html_escape("$2")."</tt>" :
			"<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'accesses') {
	return &text('log_'.$action.'_accesses', $object);
	}
elsif ($action eq 'sfile' || $action eq 'sup' || $action eq 'sdown') {
	return &text('log_'.$action, "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'boot') {
	return $object ? $text{'log_bootup'} : $text{'log_bootdown'};
	}
elsif ($action eq 'create') {
	return &text('log_create', "<tt>".&html_escape($object)."</tt>");
	}
else {
	return $text{'log_'.$action};
	}
}

