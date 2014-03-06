# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
our (%text);
do 'webalizer-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "log") {
	return &text("log_${action}_log", "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq "logs") {
	return &text("log_${action}_logs", $object);
	}
elsif ($type eq "global") {
	return $object eq "-" ? $text{"log_global"} :
		&text("log_global2", "<tt>".&html_escape($object)."</tt>");
	}
}

