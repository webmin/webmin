# log_parser.pl
# Functions for parsing this module's logs

do 'cron-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq "env") {
	return &text('log_env_'.$action, "<tt>$object</tt>");
	}
elsif ($type eq "crons") {
	return &text('log_crons_'.$action, $object);
	}
elsif ($action eq "move") {
	return &text('log_move', "<tt>$object</tt>");
	}
elsif ($action eq 'modify') {
	return &text($long ? 'log_modify_l' : 'log_modify',
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'cmd'})."</tt>");
	}
elsif ($action eq 'create') {
	return &text($long ? 'log_create_l' : 'log_create',
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'cmd'})."</tt>");
	}
elsif ($action eq 'delete') {
	return &text($long ? 'log_delete_l' : 'log_delete',
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'command'})."</tt>");
	}
elsif ($action eq 'exec' || $action eq 'kill') {
	return &text($long ? 'log_'.$action.'_l' : 'log_'.$action,
		     "<tt>$object</tt>",
		     "<tt>".&html_escape($p->{'command'})."</tt>");
	}
elsif ($action eq 'allow') {
	return $text{'log_allow'};
	}
else {
	return undef;
	}
}

