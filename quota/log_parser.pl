# log_parser.pl
# Functions for parsing this module's logs

do 'quota-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
$object = &html_escape($object);
if ($action eq 'activate') {
	return &text($p->{'mode'} == 1 ? 'log_activate_u' :
		     $p->{'mode'} == 2 ? 'log_activate_g' :
		     'log_activate_ug', "<tt>$object</tt>");
	}
elsif ($action eq 'deactivate') {
	return &text($p->{'mode'} == 1 ? 'log_deactivate_u' :
		     $p->{'mode'} == 2 ? 'log_deactivate_g' :
		     'log_deactivate_ug', "<tt>$object</tt>");
	}
elsif ($action eq 'support') {
	return &text('log_support', "<tt>$object</tt>");
	}
elsif ($action eq 'save') {
	return &text('log_save', "<tt>$object</tt>",
				 "<tt>$p->{'filesys'}</tt>");
	}
elsif ($action eq 'sync') {
	return &text($type eq 'user' ? 'log_sync' : 'log_gsync',
		     "<tt>$object</tt>");
	}
elsif ($action eq 'grace') {
	return &text($type eq 'user' ? 'log_grace_u' : 'log_grace_g',
		     "<tt>$object</tt>");
	}
elsif ($action eq 'check') {
	return &text('log_check', "<tt>$object</tt>");
	}
elsif ($action eq 'copy') {
	return &text($type eq 'user' ? 'log_copy_u' : 'log_copy_g',
		     "<tt>$object</tt>");
	}
elsif ($action eq 'email') {
	return &text('log_email_'.$type, "<tt>$object</tt>");
	}
else {
	return undef;
	}
}

