# log_parser.pl
# Functions for parsing this module's logs

do 'samba-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
$object = &html_escape($object);
if ($type eq 'shares') {
	return &text("log_delete_${type}", $object);
	}
elsif ($action eq 'save') {
	if ($object eq 'global') {
		return $text{"log_default_${type}"};
		}
	else {
		return &text("log_save_${type}", "<tt>$object</tt>");
		}
	}
elsif ($action eq 'create') {
	return &text("log_create_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'delete') {
	return &text("log_delete_${type}", "<tt>$object</tt>");
	}
elsif ($action eq 'manual') {
	return &text("log_manual", "<tt>$object</tt>");
	}
elsif ($action eq 'copy') {
	return &text('log_copy', "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'copy'})."</tt>");
	}
elsif ($action eq 'epass') {
	return &text($long ? 'log_epass_l' : 'log_epass',
		     int($p->{'created'}), int($p->{'modified'}),
		     int($p->{'deleted'}));
	}
elsif ($type eq 'euser') {
	return &text("log_${action}_euser", "<tt>$object</tt>");
	}
elsif ($type eq 'group') {
	return &text("log_${action}_group", "<tt>$object</tt>");
	}
elsif ($action eq 'kill') {
	if ($p->{'share'}) {
		return &text('log_skill', "<tt>$object</tt>",
			     "<tt>".&html_escape($p->{'share'})."</tt>");
		}
	else {
		return &text('log_kill', "<tt>$object</tt>");
		}
	}
elsif ($action eq 'kills') {
	if ($p->{'share'}) {
		return &text('log_skills', $object,
			     "<tt>".&html_escape($p->{'share'})."</tt>");
		}
	else {
		return &text('log_kills', $object);
		}
	}
elsif ($text{"log_${action}"}) {
	return $text{"log_${action}"};
	}
else {
	return undef;
	}
}

