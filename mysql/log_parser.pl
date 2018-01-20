# log_parser.pl
# Functions for parsing this module's logs

do 'mysql-lib.pl';

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
elsif ($action eq 'cnf') {
	return $text{'log_cnf'};
	}
elsif ($action eq 'kill') {
	return &text('log_kill', $object);
	}
elsif ($action eq 'vars') {
	return &text('log_vars', $object);
	}
elsif ($type eq 'db') {
	return &text("log_${type}_${action}", "<tt>$object</tt>");
	}
elsif ($type eq 'dbs' || $type eq 'users' || $type eq 'hosts' ||
       $type eq 'cprivs' || $type eq 'tprivs' || $type eq 'dbprivs') {
	return &text("log_${type}_${action}", $object);
	}
elsif ($type eq 'table' || $type eq 'index' || $type eq 'view') {
	return &text("log_${type}_${action}", "<tt>$object</tt>",
		     "<tt>$p->{'db'}</tt>");
	}
elsif ($type eq 'tables') {
	return &text("log_${type}_${action}", $object,
		     "<tt>$p->{'db'}</tt>");
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
elsif ($type eq 'user' || $type eq 'perm' || $type eq 'host' ||
       $type eq 'tpriv' || $type eq 'cpriv') {
	$p->{'user'} = $text{'log_anon'}
		if ($p->{'user'} eq '-' || $p->{'user'} eq '%');
	$p->{'db'} = $text{'log_any'}
		if ($p->{'db'} eq '-' || $p->{'db'} eq '%');
	$p->{'host'} = $text{'log_any'}
		if ($p->{'host'} eq '-' || $p->{'host'} eq '%' ||
		    $p->{'host'} eq '');
	local $t = "log_${type}_${action}";
	if ($long && $text{$t.'_l'}) { $t .= '_l'; }
	return &text($t, "<tt>$p->{'user'}</tt>",
		     "<tt>$p->{'host'}</tt>", "<tt>$p->{'db'}</tt>",
		     "<tt>$p->{'table'}</tt>", "<tt>$p->{'field'}</tt>");
	}
elsif ($action eq 'backup') {
	$object = "" if ($object eq "-");
	return &text($object ? ($long ? 'log_backup_l' : 'log_backup')
			     : ($long ? 'log_backup_all_l' : 'log_backup_all'),
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'file'})."</tt>");
	}
elsif ($action eq 'execfile') {
	return &text($p->{'mode'} ? 'log_execupload' : 'log_execfile',
		     "<tt>".&html_escape($p->{'file'})."</tt>");
	}
elsif ($action eq 'import') {
	return &text($p->{'mode'} ? 'log_importupload' : 'log_importfile',
		     "<tt>".&html_escape($p->{'file'})."</tt>");
	}
elsif ($action eq 'set') {
	return &text('log_set', $object);
	}
elsif ($action eq 'root') {
	return $text{'log_root'};
	}
elsif ($action eq 'manual') {
	return $text{'log_manual'};
	}
else {
	return undef;
	}
}

