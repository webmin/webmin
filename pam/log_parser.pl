# log_parser.pl
# Functions for parsing this module's logs

do 'pam-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'pam') {
	return &text("log_pam_$action", "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'mod') {
	if ($action eq 'move') {
		return &text($long ? "log_mod_move_l" : "log_mod_move",
			     &short_mod($p->{'1'}), &short_mod($p->{'2'}),
			     &html_escape($object));
		}
	else {
		return &text("log_mod_$action", &short_mod($p->{'module'}),
			     &html_escape($object));
		}
	}
elsif ($type eq 'inc') {
	return &text("log_inc_$action", &html_escape($p->{'module'}),
		     &html_escape($object));
	}
elsif ($type eq 'incs') {
	return &text('log_incs', &html_escape($p->{'module'}));
	}
else {
	return undef;
	}
}

sub short_mod
{
$_[0] =~ /([^\/]+)$/;
return "<tt>".&html_escape("$1")."</tt>";
}

