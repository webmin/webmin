# log_parser.pl
# Functions for parsing this module's logs

do 'shell-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($action eq "run") {
	return &text('log_run', "<tt>$p->{'cmd'}</tt>");
	}
elsif ($action eq "clear") {
	return $text{'log_clear'};
	}
}

