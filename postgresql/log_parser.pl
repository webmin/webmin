# log_parser.pl
# Functions for parsing this module's logs

do 'postgresql-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'stop') {
	return $text{'log_stop'};
	}
elsif ($action eq 'start') {
	return $text{'log_start'};
	}
elsif ($action eq 'setup') {
	return $text{'log_setup'};
	}
elsif ($type eq 'db') {
	return &text("log_${type}_${action}", "<tt>$object</tt>");
	}
elsif ($type eq 'dbs' || $type eq 'users' || $type eq 'hosts') {
	return &text("log_${type}_${action}", $object);
	}
elsif ($type eq 'table' || $type eq 'view' || $type eq 'index') {
	return &text("log_${type}_${action}", "<tt>$object</tt>",
		     "<tt>$p->{'db'}</tt>");
	}
elsif ($type eq 'tables') {
	return &text("log_${type}_${action}", $object, "<tt>$p->{'db'}</tt>");
	}
elsif ($type eq 'field') {
	$p->{'size'} =~ s/\s+$//;
	return &text("log_${type}_${action}", "<tt>$object</tt>",
		     "<tt>$p->{'table'}</tt>", "<tt>$p->{'db'}</tt>",
		     "<tt>$p->{'type'}$p->{'size'}</tt>");
	}
elsif ($type eq 'fields') {
        return &text("log_${type}_${action}", $object,
                     "<tt>$p->{'table'}</tt>", "<tt>$p->{'db'}</tt>");
        }
elsif ($type eq 'data') {
	return &text("log_${type}_${action}", "<tt>$object</tt>",
		     "<tt>$p->{'table'}</tt>", "<tt>$p->{'db'}</tt>");
	}
elsif ($action eq 'exec') {
	return &text($long ? 'log_exec_l' : 'log_exec', "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'cmd'})."</tt>");
	}
elsif ($type eq 'user' || $type eq 'group') {
	return &text("log_${action}_${type}", "<tt>$object</tt>");
	}
elsif ($type eq 'hba') {
	return $object eq 'local' ? $text{"log_${action}_local"} :
	       $object eq 'all' ? $text{"log_${action}_all"} :
	       &text("log_${action}_hba", "<tt>$object</tt>");
	}
elsif ($action eq 'grant') {
	return &text('log_grant', "<tt>$object</tt>", "<tt>$p->{'db'}</tt>");
	}
elsif ($action eq 'degrant') {
	return &text('log_degrant', $object);
	}
elsif ($action eq 'backup') {
	$object = "" if ($object eq "-");
	return &text($object ? ($long ? 'log_backup_l' : 'log_backup')
			     : ($long ? 'log_backup_all_l' : 'log_backup_all'),
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'file'})."</tt>");
	}
elsif ($action eq 'manual') {
	return $text{'log_manual'};
	}
else {
	return undef;
	}
}

