# log_parser.pl
# Functions for parsing this module's logs
use strict;
use warnings;
our %text;

do 'at-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq "job") {
	return &text('log_'.$action.'_job',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq "jobs") {
	return &text('log_'.$action.'_jobs', $object);
	}
elsif ($action eq 'allow') {
	return $text{'log_allow'};
	}
else {
	return undef;
	}
}

