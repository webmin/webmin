# log_parser.pl
# Functions for parsing this module's logs

do 'xinetd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'serv') {
	return &text("log_${action}_serv",
		     "<tt>".&html_escape($object)."</tt>",
		     uc($p->{'protocol'}));
	}
elsif ($action eq "enable" || $action eq "disable") {
	if ($long && $p->{'servs'}) {
		return &text('log_'.$action.'_l',
		     join(", ", map { "<tt>$_</tt>" } split(/\0/, $p->{'servs'})));
		}
	else {
		return &text('log_'.$action, $object);
		}
	}
else {
	return $text{'log_'.$action};
	}
}

