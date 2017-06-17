# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'firewalld-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "port" || $type eq "serv" || $type eq "forward") {
	return &text("log_${action}_${type}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq "rules") {
	return &text("log_${action}_${type}", &html_escape($object));
	}
elsif ($type eq "zone") {
	return &text("log_${action}_${type}",
		     "<tt>".&html_escape($object)."</tt>");
	}
else {
	return $text{"log_${action}"};
	}
}

