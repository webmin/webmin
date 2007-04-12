# log_parser.pl
# Functions for parsing this module's logs

do 'pptp-client-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
$object = "<tt>". &html_escape($object)."</tt>";
if ($type eq 'tunnel') {
	return &text('log_'.$action, $object);
	}
elsif ($action eq 'conn') {
	if ($p->{'address'}) {
		return &text($long ? 'log_conn_l' : 'log_conn',
			     $object, $p->{'address'});
		}
	else {
		return &text('log_failed', $object);
		}
	}
elsif ($action eq 'disc') {
	return &text('log_disc', $object);
	}
else {
	return $text{'log_'.$action};
	}
}

