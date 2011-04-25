# log_parser.pl
# Functions for parsing this module's logs

do 'webminlog-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq 'rollback') {
	return &text('log_rollback', "<i>".$p->{'desc'}."</i>",
				     "<i>".$p->{'mdesc'}."</i>");
	}
return undef;
}

1;

