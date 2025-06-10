# log_parser.pl
# Functions for parsing this module's logs

do 'webmincron-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'run') {
	if ($p->{'error'}) {
		return &text('log_failure', $p->{'module'}, $p->{'func'},
					    &html_escape($p->{'error'}));
		}
	else {
		return &text('log_success', $p->{'module'}, $p->{'func'});
		}
	}
else {
	return undef;
	}
}

